module Utilities
  extend self

  # Convert String with Time info to its epoch FixNum previously setting to zero the seconds
  def to_epoch value
    parsed = Time.parse(value)
    zeroed = Time.new(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.min, 0, 0)
    zeroed.to_i
  end

  def to_epoch_milis value
    (to_epoch (value)) * 1000
  end

  def to_milis_zero_out_from_seconds value
    parsed_value = Time.strptime(value.to_s,'%s').utc
    zeroed = Time.new(parsed_value.year, parsed_value.month, parsed_value.day, parsed_value.hour, parsed_value.min, 0, 0)
    zeroed.to_i*1000
  end

  def to_milis_zero_out_from_hour value
    parsed_value = Time.strptime(value.to_s,'%s').utc
    zeroed = Time.new(parsed_value.year, parsed_value.month, parsed_value.day, 0, 0, 0, 0)
    zeroed.to_i*1000
  end
end
