module SplitIoClient
  module Utilities
    extend self

    # Convert String with Time info to its epoch FixNum previously setting to zero the seconds
    def to_epoch(value)
      parsed = Time.parse(value)
      zeroed = Time.new(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.min, 0, 0)

      zeroed.to_i
    end

    def to_epoch_milis(value)
      to_epoch(value) * 1000
    end

    def to_milis_zero_out_from_seconds(value)
      parsed_value = Time.strptime(value.to_s, '%s').utc
      zeroed = Time.new(parsed_value.year, parsed_value.month, parsed_value.day, parsed_value.hour, parsed_value.min, 0, 0)

      zeroed.to_i * 1000
    rescue StandardError
      return :non_valid_date_info
    end

    def to_milis_zero_out_from_hour(value)
      parsed_value = Time.strptime(value.to_s, '%s').utc
      zeroed = Time.new(parsed_value.year, parsed_value.month, parsed_value.day, 0, 0, 0, 0)

      zeroed.to_i * 1000
    rescue StandardError
      return :non_valid_date_info
    end

    def randomize_interval(interval)
      random_factor = Random.new.rand(50..100) / 100.0

      interval * random_factor
    end

    def split_bulk_to_send(hash, divisions)
      count = 0

      hash.each_with_object([]) do |key_value, final|
        final[count % divisions] ||= {}
        final[count % divisions][key_value[0]] = key_value[1]
        count += 1
      end
    rescue StandardError
      []
    end
  end  
end
