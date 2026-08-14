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

## 4. Proposed fixes, in priority order

### Fix 1 (P0) — Distinguish intentional close from connection failure

Give `Client` an explicit "shutting down" flag so a reader thread that wakes to a
closed/nil socket during a deliberate close exits **silently** instead of pushing
`PUSH_RETRYABLE_ERROR`. This alone breaks the self-sustaining loop.

```ruby
def initialize(...)
  ...
  @shutdown = Concurrent::AtomicBoolean.new(false)
end

def close(status = nil)
  return if @socket.nil?
  @shutdown.make_true
  ...
end

# in connect_stream, before returning PUSH_RETRYABLE_ERROR from any rescue:
return nil if @shutdown.value
```

and set `@shutdown.make_false` in `socket_write` when a new connection begins.

### Fix 2 (P0) — Make each connect_stream thread own its socket

Stop sharing `@socket` / `@first_event` / `@connected` across generations. Pass
the socket into `connect_stream` as a local, and tag each attempt with a
generation counter; a thread exits immediately if its generation is stale:

```ruby
def connect_thread(latch)
  generation = @generation.increment
  socket = nil
  thread = Thread.new do
    socket = socket_connect_and_write(latch) or next
    connect_stream(socket, generation, latch)
  end
  reap_previous_threads   # see Fix 3
  @config.threads[:connect_stream] = thread
end
```

Every loop iteration checks `return nil unless generation == @generation.value`.
This makes a leaked thread structurally impossible and eliminates byte-stealing.

### Fix 3 (P0) — Never orphan a thread handle

Before overwriting `@config.threads[:connect_stream]`, join the previous thread
with a bounded timeout and kill it if it does not exit:

```ruby
prev = @config.threads[:connect_stream]
if prev&.alive?
  @config.logger.warn('Previous connect_stream thread still alive; terminating')
  prev.join(1) || Thread.kill(prev)
end
```

Apply the identical pattern to `:schedule_next_token_refresh` in `PushManager`.

### Fix 4 (P1) — Make `process_disconnect` idempotent / re-entrancy-safe

`process_disconnect(true)` must not launch a reconnect if one is already in
progress. Add a `@reconnecting` `AtomicBoolean` guard (compare-and-set), cleared
once `start_sse` returns. Also drain/coalesce duplicate `PUSH_RETRYABLE_ERROR`
entries already sitting in `@status_queue` before reconnecting — during a storm
the queue holds hundreds of them, each of which will fire another cycle.

### Fix 5 (P1) — Rate-limit reconnects regardless of backoff state

The current design allows an unbounded reconnect rate because `PUSH_CONNECTED`
resets backoff to `0`. Fast recovery after a *genuinely long-lived* connection is
reasonable; fast recovery after a connection that lasted 15 ms is not. Two
options, not mutually exclusive:

- **Minimum-uptime gate (recommended):** only `@back_off.reset` if the connection
  stayed up for a meaningful period (e.g. ≥ 30 s / one keepalive interval).
  Otherwise let `@attempt` keep growing. This is a one-line change in
  `incoming_push_status_handler` plus a connected-at timestamp, and preserves the
  intended fast-recovery semantics that @Agustin described.
- **Floor the interval:** enforce a small non-zero minimum (e.g. 1 s) in
  `BackOff#interval`, capping the worst case at ~1 reconnect/sec instead of ~64.

Note on the codepulse comment: making `BackOff#reset` restore the
constructor-supplied `@initial_attempt` instead of `0` is a *defensible*
consistency fix — `SyncManager` deliberately passes `BackOff.new(1, 3)` (first
backoff = 8 s) and `reset` silently discards that intent. But it is **not the
root cause**, and per @Agustin's comment, a 0-delay retry after a real success is
the intended behaviour. Prefer the minimum-uptime gate above; if `reset` is
changed, do it as a separate, deliberate decision.

### Fix 6 (P1) — Fix the observability gap (overlaps FME-18152)

`client.rb:124` uses `rescue Exception` (catches `SignalException`, `Interrupt`,
`NoMemoryError`) and logs at `debug` only when `debug_enabled`. Change to:

```ruby
rescue StandardError => e
  @config.logger.warn("SSE connection lost, will reconnect: #{e.class}: #{e.message}")
  return Constants::PUSH_RETRYABLE_ERROR
```

Also add a periodic `warn` when reconnect frequency exceeds a threshold (e.g.
>5 reconnects/minute) and log `Thread.list.size` alongside it — so the next
occurrence is diagnosable from a customer's default-level logs.

### Suggested regression tests

1. **No spurious error on intentional close** — connect, `close`, assert the
   status queue contains no `PUSH_RETRYABLE_ERROR`. (Currently fails: 9/15.)
2. **No thread leak across restarts** — the `process_data`-busy repro in §2:
   collect each `config.threads[:connect_stream]` across N cycles, assert all
   prior threads are dead. (Currently fails.)
3. **Reconnect rate bound** — drive M synthetic `PUSH_RETRYABLE_ERROR` events
   and assert `start_sse` is invoked at most once per outstanding disconnect and
   no faster than the backoff floor.
4. **Storm soak** — 200 close/start cycles; assert `Thread.list.size` stays
   bounded.

---

## Summary

| Question | Answer |
|---|---|
| Is the issue valid? | **Yes**, reproduced locally. |
| Multiple streaming threads accumulating? | **Yes**, reproduced — single-slot thread handle + shared mutable socket state. |
| Root cause | `close()` is indistinguishable from connection failure → spurious `PUSH_RETRYABLE_ERROR` → unguarded reconnect with 0 backoff → new thread each time, old one leaked and itself a new error source. Compounds without bound. |
| Is `BackOff#reset` the bug? | **No.** Contributing factor (0-delay retry), not root cause. |
| Customer-specific? | **No.** SDK fix required. |
| Blocker for diagnosis | `rescue Exception` + debug-only logging at `client.rb:124` (FME-18152) hid 99% of the incident. |
