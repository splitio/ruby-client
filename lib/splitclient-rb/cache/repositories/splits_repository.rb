require 'concurrent'

module SplitIoClient
  module Cache
    module Repositories
      class SplitsRepository < Repository
        attr_reader :adapter
        DEFAULT_CONDITIONS_TEMPLATE = [{
          conditionType: "ROLLOUT",
          matcherGroup: {
              combiner: "AND",
              matchers: [
              {
                  keySelector: nil,
                  matcherType: "ALL_KEYS",
                  negate: false,
                  userDefinedSegmentMatcherData: nil,
                  whitelistMatcherData: nil,
                  unaryNumericMatcherData: nil,
                  betweenMatcherData: nil,
                  dependencyMatcherData: nil,
                  booleanMatcherData: nil,
                  stringMatcherData: nil
              }]
          },
          partitions: [
              {
              treatment: "control",
              size: 100
              }
          ],
          label: "unsupported matcher type"
        }]

        def initialize(config, flag_sets_repository, flag_set_filter)
          super(config)
          @tt_cache = {}
          @adapter = case @config.cache_adapter.class.to_s
          when 'SplitIoClient::Cache::Adapters::RedisAdapter'
            SplitIoClient::Cache::Adapters::CacheAdapter.new(@config)
          else
            @config.cache_adapter
          end
          @flag_sets = flag_sets_repository
          @flag_set_filter = flag_set_filter
          unless @config.mode.equal?(:consumer)
            @adapter.set_string(namespace_key('.splits.till'), '-1')
            @adapter.initialize_map(namespace_key('.segments.registered'))
          end
        end

        def update(to_add, to_delete, new_change_number)
          to_add.each{ |feature_flag| add_feature_flag(feature_flag) }
          to_delete.each{ |feature_flag| remove_feature_flag(feature_flag) }
          set_change_number(new_change_number)
        end

        def get_split(name)
          split = @adapter.string(namespace_key(".split.#{name}"))

          JSON.parse(split, symbolize_names: true) if split
        end

        def splits(filtered_names=nil)
          symbolize = true
          if filtered_names.nil?
            filtered_names = split_names
            symbolize = false
          end
          get_splits(filtered_names, symbolize)
        end

        def traffic_type_exists(tt_name)
          case @adapter
          when SplitIoClient::Cache::Adapters::CacheAdapter
            tt_count = @adapter.string(namespace_key(".trafficType.#{tt_name}"))
            begin
              !tt_count.nil? && Integer(tt_count, 10) > 0
            rescue StandardError => e
              @config.logger.error("Error while parsing Traffic Type count: #{e.message}")
              false
            end
          else
            @tt_cache.key?(tt_name) && @tt_cache[tt_name] > 0
          end
        end

        # Return an array of Split Names excluding control keys like splits.till
        def split_names
          @adapter.find_strings_by_prefix(namespace_key('.split.'))
            .map { |split| split.gsub(namespace_key('.split.'), '') }
        end

        def set_change_number(since)
          @adapter.set_string(namespace_key('.splits.till'), since)
        end

        def get_change_number
          @adapter.string(namespace_key('.splits.till'))
        end

        def set_segment_names(names)
          return if names.nil? || names.empty?

          names.each do |name|
            @adapter.add_to_set(namespace_key('.segments.registered'), name)
          end
        end

        def exists?(name)
          @adapter.exists?(namespace_key(".split.#{name}"))
        end

        def ready?
          @adapter.string(namespace_key('.splits.ready')).to_i != -1
        end

        def not_ready!
          @adapter.set_string(namespace_key('.splits.ready'), -1)
        end

        def ready!
          @adapter.set_string(namespace_key('.splits.ready'), Time.now.utc.to_i)
        end

        def clear
          @tt_cache.clear

          @adapter.clear(namespace_key)
        end

        def kill(change_number, split_name, default_treatment)
          split = get_split(split_name)

          return if split.nil?

          split[:killed] = true
          split[:defaultTreatment] = default_treatment
          split[:changeNumber] = change_number

          @adapter.set_string(namespace_key(".split.#{split_name}"), split.to_json)
        end

        def splits_count
          split_names.length
        end

        def get_feature_flags_by_sets(flag_sets)
          sets_to_fetch = Array.new
          flag_sets.each do |flag_set|
            unless @flag_sets.flag_set_exist?(flag_set)
              @config.logger.warn("Flag set #{flag_set} is not part of the configured flag set list, ignoring it.")
              next
            end
            sets_to_fetch.push(flag_set)
          end
          @flag_sets.get_flag_sets(flag_sets)
        end

        def is_flag_set_exist(flag_set)
          @flag_sets.flag_set_exist?(flag_set)
        end

        def flag_set_filter
          @flag_set_filter
        end

        private

        def add_feature_flag(split)
          return unless split[:name]
          existing_split = get_split(split[:name])

          if(!existing_split)
            increase_tt_name_count(split[:trafficTypeName])
          elsif(existing_split[:trafficTypeName] != split[:trafficTypeName])
            increase_tt_name_count(split[:trafficTypeName])
            decrease_tt_name_count(existing_split[:trafficTypeName])
            remove_from_flag_sets(existing_split)
          elsif(existing_split[:sets] != split[:sets])
            remove_from_flag_sets(existing_split)
          end

          if check_undefined_matcher(split)
            @config.logger.warn("Feature Flag #{split[:name]} has undefined matcher, setting conditions to default template.")
            split[:conditions] = SplitsRepository::DEFAULT_CONDITIONS_TEMPLATE
          end
          if !split[:sets].nil?
            for flag_set in split[:sets]
              if !@flag_sets.flag_set_exist?(flag_set)
                if @flag_set_filter.should_filter?
                  next
                end
                @flag_sets.add_flag_set(flag_set)
              end
              @flag_sets.add_feature_flag_to_flag_set(flag_set, split[:name])
            end
          end

          @adapter.set_string(namespace_key(".split.#{split[:name]}"), split.to_json)
        end

        def check_undefined_matcher(split)
          for condition in split[:conditions]
            for matcher in condition[:matcherGroup][:matchers]
              if !SplitIoClient::Condition.instance_methods(false).map(&:to_s).include?("matcher_#{matcher[:matcherType].downcase}")
                @config.logger.error("Detected undefined matcher #{matcher[:matcherType].downcase} in feature flag #{split[:name]}")
                return true
              end
            end
          end
          return false
        end

        def remove_feature_flag(split)
          decrease_tt_name_count(split[:trafficTypeName])
          remove_from_flag_sets(split)
          @adapter.delete(namespace_key(".split.#{split[:name]}"))
        end

        def get_splits(names, symbolize_names = true)
          splits = {}
          split_names = names.map { |name| namespace_key(".split.#{name}") }
          splits.merge!(
            @adapter
              .multiple_strings(split_names)
              .map { |name, data| [name.gsub(namespace_key('.split.'), ''), data] }.to_h
          )

          splits.map do |name, data|
            parsed_data = data ? JSON.parse(data, symbolize_names: true) : nil
            split_name = symbolize_names ? name.to_sym : name
            [split_name, parsed_data]
          end.to_h
        end

        def remove_from_flag_sets(feature_flag)
          name = feature_flag[:name]
          flag_sets = get_split(name)[:sets] if exists?(name)
          if !flag_sets.nil?
            for flag_set in flag_sets
              @flag_sets.remove_feature_flag_from_flag_set(flag_set, feature_flag[:name])
              if is_flag_set_exist(flag_set) && @flag_sets.get_flag_sets([flag_set]).length == 0 && !@flag_set_filter.should_filter?
                  @flag_sets.remove_flag_set(flag_set)
              end
            end
          end
        end

        def increase_tt_name_count(tt_name)
          return unless tt_name

          @tt_cache[tt_name] = 0 unless @tt_cache[tt_name]
          @tt_cache[tt_name] += 1
        end

        def decrease_tt_name_count(tt_name)
          return unless tt_name

          @tt_cache[tt_name] -= 1 if @tt_cache[tt_name]
          @tt_cache.delete(tt_name) if @tt_cache[tt_name] == 0
        end
      end
    end
  end
end
