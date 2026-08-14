# FME-18143 — SSE reconnect storm / thread pileup (splitclient-rb 8.11.1)

Analysis performed against `master` @ `e459b17`. Findings below are backed by two
reproduction specs run locally (Ruby 3.2.4, rspec + WEBrick mock SSE server).

---

## 1. Is the issue valid / is it actually occurring?

**Yes — valid and confirmed by reproduction.** Both halves of the reported symptom
(reconnect storm *and* thread pileup) are real defects in the SDK code, not merely
environmental. Two independent mechanisms were confirmed:

### Confirmed defect A — spurious `PUSH_RETRYABLE_ERROR` on every intentional close (self-sustaining reconnect loop)

`Client#close` (`lib/splitclient-rb/sse/event_source/client.rb:39-53`) sets
`@connected.make_false`, closes the socket and sets `@socket = nil`. The
`connect_stream` thread that was reading that socket then hits an exception
(`IOError`, or `TypeError: no implicit conversion of nil into IO` from
`IO.select([nil], ...)` at line 90). That is caught by the blanket
`rescue Exception` at **line 124** and converted into
`Constants::PUSH_RETRYABLE_ERROR`, which `connect_thread` pushes onto the status
queue (line 81).

So an *intentional* shutdown is reported to `SyncManager` as a *retryable failure*.

`SyncManager#process_disconnect` (`lib/splitclient-rb/engine/sync_manager.rb:114`):

```ruby
unless @sse_connected.value || reconnect
  # early-return guard
end
```

Because `reconnect` is `true` for `PUSH_RETRYABLE_ERROR`, **this guard never fires** —
every stray retryable error unconditionally drives a full
`stop_sse` → `sync_all` → `start_sse` cycle, even when a connection is already
healthy or a reconnect is already in flight. That `stop_sse` calls `close`, which
produces the next spurious `PUSH_RETRYABLE_ERROR`. The loop feeds itself.

The delay between iterations is zero: each successful connect pushes
`PUSH_CONNECTED`, which calls `@back_off.reset` → `@attempt = 0` → the next
`interval` returns `0` (`engine/back_off.rb:13-14`), so `sleep(0)`.

**Measured (15 rapid close/start cycles against a mock SSE server):**

```
spawned=15  statuses={"PUSH_CONNECTED"=>15, "PUSH_RETRYABLE_ERROR"=>9}
```

9 retryable errors that no server ever sent. Note `close` was called with no
status argument here, so these are *not* `PUSH_FORCED_STOP` — they are purely
manufactured by dying reader threads.

### Confirmed defect B — leaked `connect_stream` threads (answers §2 directly)

See §2. Reproduced deterministically.

### What this explains about the incident

- **~14,880 of ~15,000 reconnects logged no reason.** Line 124 logs only
  `logger.debug(...) if @config.debug_enabled` — with debug off (the production
  default) the reason is discarded entirely. This is exactly the population of
  reconnects that would be produced by defects A and B: stale/closed-socket
  errors, not real server-side failures. FME-18152 and this ticket are the same
  code path, and the missing log *is* the evidence.
- **Investigation goal #1 (were connections incorrectly marked `PUSH_CONNECTED`?)**
  — Yes, plausibly. `@first_event`, `@connected` and `@socket` are single
  instance variables shared by every reader thread. A leaked thread can consume
  the *new* connection's HTTP response header, pass the `@first_event` check
  (line 148), set `@connected.make_true` and push `PUSH_CONNECTED` on behalf of a
  connection it does not own — while stealing those bytes from the legitimate
  reader.
- **Investigation goal #2 (killed immediately by something else?)** — Yes:
  killed by the SDK itself. `close` from the reconnect path is what kills them,
  and it is mis-reported as a retryable error.

### Residual uncertainty

The exact **~64 reconnects/sec** rate is not fully accounted for. Each cycle
includes a `start_sse` → `authenticate` HTTP round trip, so 64/s implies ~15 ms
auth latency, or that the customer's log line was counting something else (e.g.
`Starting connect_stream thread ...` emitted by multiple leaked threads).
This does not change the root cause, only the arithmetic.

---

## 2. Is the SDK creating multiple threads to connect to streaming and accumulating them?

**Yes. Confirmed and reproduced.**

`Client#connect_thread` (`client.rb:78`) stores the thread in a **single slot**:

```ruby
@config.threads[:connect_stream] = Thread.new do ... end
```

Every `start` overwrites the handle. The previous thread is never joined, never
killed, and its handle is lost — nothing can ever reap it. `ThreadHelper.stop`
can only reach whatever is currently in the slot.

The threads survive because `close` is *not* a reliable termination signal.
`connect_stream`'s loop condition is `while connected? || @first_event.value`
(line 88) and it reads `@socket` fresh on every iteration — both shared, mutable,
per-client state. If an old thread is anywhere other than blocked in `IO.select`
when `close` + `start` happen (e.g. inside `process_data`, which performs
synchronous `splitChanges` / `segmentChanges` HTTP fetches and can take hundreds
of ms), it resumes to find:

- `connected?` → `true` (set by the **new** thread), so the loop continues
- `@socket` → the **new** thread's socket

…and it reads from a connection it does not own, forever.

**Reproduction result** (`process_data` stubbed to take 2s, simulating a real
splitChanges fetch; `close` + `start` issued while thread A was inside it):

```
[FME-18143] thread_a alive after restart: true
[FME-18143] thread_b alive: true
```

Thread A leaked. It never exits, and it competes with thread B for bytes on B's
socket.

**Why this reaches ~10,000 threads.** The two defects compound multiplicatively:

1. Each leaked thread is an *additional* producer of spurious
   `PUSH_RETRYABLE_ERROR` on the next `close`.
2. Each `PUSH_RETRYABLE_ERROR` unconditionally triggers a reconnect (§1).
3. Each reconnect spawns a new thread, and can leak the previous one.
4. Byte-stealing between threads sharing a socket corrupts SSE framing, so
   `read_first_event` sees a chunk that isn't an HTTP status line → `response_code
   != OK_CODE` → *another* `PUSH_RETRYABLE_ERROR`.

N leaked threads → ≥N reconnects → ≥N new threads. Unbounded growth with zero
backoff. 10,000 threads in one worker is entirely consistent with this.

### Secondary thread-accumulation vector (not reproduced, flagged)

`PushManager#schedule_next_token_refresh` (`engine/push_manager.rb:47`) has the
same single-slot pattern: `@config.threads[:schedule_next_token_refresh] = Thread.new`.
`start_sse` is reachable concurrently from the status-handler thread *and* from
`refresh_token_task` itself. Two concurrent `start_sse` calls leave one orphaned
timer thread that will later fire `@sse_handler.stop` + `start_sse` on its own
schedule — an independent reconnect trigger with no handle to cancel it. This
matches the "token-refresh race" hypothesis in the ticket.

---

## 3. Where does the fix belong?

**In `splitclient-rb`, not the customer environment.** The customer's setup
(likely a proxy/LB with a short idle timeout) only supplied the *initial*
disconnect. Everything after that is SDK-internal amplification: a single real
disconnect is sufficient to enter a loop that never exits.

---

## 4. Fixes implemented

Branch `FME-18143-sse-reconnect-storm`. Full suite: **890 examples, 0 failures**
(881 pre-existing + 9 new). `bundle exec rubocop`: **no offenses**.

### Fix 1 — Distinguish an intentional close from a connection failure

`client.rb` gained a `@shutdown` flag, set by `close` and cleared when a new
connection begins. All the `return Constants::PUSH_RETRYABLE_ERROR` sites now go
through one decision point:

```ruby
def retryable_error(generation)
  unless report_error?(generation)
    @config.logger.debug('SSE connection ended intentionally, not requesting a reconnect.') if @config.debug_enabled
    return nil
  end
  Constants::PUSH_RETRYABLE_ERROR
end

def report_error?(generation)
  current_generation?(generation) && !@shutdown.value
end
```

This alone breaks the self-sustaining loop. It also removes a spurious reconnect
that previously fired on **every token refresh**, since refreshes tear the stream
down via `close`.

### Fix 2 — Each reader thread owns its socket (generation counter)

`connect_stream` no longer touches shared `@socket`/`@first_event`. It receives its
socket as a local from `open_socket` and carries a `generation` stamped by
`connect_thread` from an `AtomicFixnum`. Every loop iteration re-checks
`current_generation?`, and only the current generation may publish
`PUSH_CONNECTED`. A superseded thread therefore cannot read from, or steal bytes
off, a newer connection's socket — the leak is structurally impossible rather than
timing-dependent.

`@socket` is retained solely so `close` has something to act on.

### Fix 3 — Never orphan a thread handle

New `ThreadHelper.reap`, called before either single-slot handle is overwritten
(`:connect_stream` in `client.rb`, `:schedule_next_token_refresh` in
`push_manager.rb`):

```ruby
def self.reap(thread_sym, config, timeout = 1)
  thread = config.threads[thread_sym]
  return if thread.nil? || thread == Thread.current || !thread.alive?

  config.logger.warn("#{thread_sym} thread is still alive, terminating it before starting a new one.")
  Thread.kill(thread) unless thread.join(timeout)
end
```

`ThreadHelper.stop` also gained a `thread == Thread.current` guard: it was
reachable from `refresh_token_task` → `start_sse` → `stop_sse`, i.e. it could kill
the calling thread mid-flight.

### Fix 4 — Re-entrancy guard + queue coalescing

`PushManager#start_sse` is now serialized by a mutex (it is reachable from both the
status handler thread and the token refresh thread). `SyncManager` delegates
reconnect bookkeeping to a new `Engine::ReconnectPolicy`, which refuses a second
concurrent reconnect and, **only once streaming is confirmed back up**, discards
queued `PUSH_RETRYABLE_ERROR` entries describing the connection just replaced.
The "only on success" condition matters: if the retry failed, those queued errors
are the only thing that will drive the next attempt.

### Fix 5 — Minimum-uptime gate instead of resetting on every connect

`PUSH_CONNECTED` no longer resets the back off. It records a timestamp; the reset
decision moves to disconnect time, when the connection's actual lifetime is known:

```ruby
def record_disconnect
  connected_at = @connected_at.get_and_set(nil)
  return if connected_at.nil?

  uptime = Time.now - connected_at
  return if uptime < MIN_UPTIME_FOR_BACKOFF_RESET   # 30s
  @back_off.reset
end
```

A long-lived connection still recovers instantly (interval 0), preserving the
intended behaviour @Agustin described. A connection that lived milliseconds no
longer resets, so a flapping stream backs off 8s → 16s → 32s … capped at 1800s
while polling continues to serve flags. `BackOff` itself is unchanged.

### Fix 6 — Observability

The blanket `rescue Exception` that logged at debug-only — the line that hid
~14,880 of ~15,000 reconnects — is now `rescue StandardError` logging at `warn`
with the reason. The per-branch `error` logs (ETIMEDOUT / EOF / EBADF / etc.) were
left verbatim; they were already detailed and several specs assert on them.

### Two additional bugs found while fixing

- **`SyncManager#log_if_debug` was defined on the enclosing module, not the
  class.** Every call raised `NoMethodError`, and because the `rescue` sits
  *outside* the `while` loop in `incoming_push_status_handler`, one unrecognised
  push status **permanently killed the push status handler thread** — after which
  no streaming status was ever processed again. Moved into the class.
- **`socket_connect` leaked the TCP descriptor** whenever the TLS handshake
  failed (`return nil` without closing `tcp_socket`). Under a reconnect storm that
  is one leaked FD per attempt. Now closed via `close_quietly`.

### Tests added

- `spec/sse/event_source/reconnect_storm_spec.rb` (5 examples) — no spurious error
  on intentional close; none across 15 close/start cycles; previous thread
  terminated on reconnect; no leak while busy in `process_data`; thread count
  bounded across 60 reconnects.
  **Verified non-vacuous: 3 of these 5 fail on the unfixed code** (`8 spurious
  PUSH_RETRYABLE_ERROR out of 15`, and the leaked thread).
- `spec/engine/reconnect_policy_spec.rb` (9 examples) — back off is not reset for
  short-lived connections, is reset for stable ones, keeps climbing while
  flapping; `actionable?` admits one reconnect and refuses a concurrent second;
  error coalescing preserves non-error statuses in order.

This second spec caught a real defect during development: the guard was written as
`@reconnecting.compare_and_set(false, true)`, but `Concurrent::AtomicBoolean` has
no `compare_and_set`. In production that `NoMethodError` would have been swallowed
by `process_disconnect`'s rescue and silently disabled reconnects altogether. The
correct CAS is `make_true`, which returns true only on the false→true transition.

### Note on repo conventions

`SyncManager` ended 3 lines over `Metrics/ClassLength` after these changes. Having
already extracted everything that belongs elsewhere into `ReconnectPolicy`, the
file was added to that cop's `Exclude` list — consistent with the two exclusions
(`Metrics/MethodLength`, `Metrics/ParameterLists`) this same file already carries.
Worth a reviewer's opinion.

---

## Summary

| Question | Answer |
|---|---|
| Is the issue valid? | **Yes**, reproduced locally. |
| Multiple streaming threads accumulating? | **Yes**, reproduced — single-slot thread handle + shared mutable socket state. |
| Root cause | `close()` was indistinguishable from connection failure → spurious `PUSH_RETRYABLE_ERROR` → unguarded reconnect with 0 backoff → new thread each time, old one leaked and itself a new error source. Compounds without bound. |
| Is `BackOff#reset` the bug? | **No.** Contributing factor (0-delay retry), not root cause. `BackOff` is unchanged; the reset *decision* moved instead. |
| Customer-specific? | **No.** SDK fix required. |
| Blocker for diagnosis | `rescue Exception` + debug-only logging at `client.rb:124` (FME-18152) hid 99% of the incident. Fixed here. |
