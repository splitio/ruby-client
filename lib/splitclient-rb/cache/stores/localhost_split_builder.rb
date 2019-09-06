# frozen_string_literal: true

module SplitIoClient
  module Cache
    module Stores
      class LocalhostSplitBuilder
        class << self
          def build_splits(splits)
            splits.map do |feature, treatments|
              build_split(feature, treatments)
            end
          end

          private

          def build_split(feature, treatments)
            {
              name: feature,
              status: 'ACTIVE',
              killed: false,
              trafficAllocation: 100,
              seed: 2_089_907_429,
              defaultTreatment: 'control_treatment',
              configurations: build_configurations(treatments),
              conditions: build_conditions(treatments)
            }
          end

          def build_configurations(treatments)
            treatments.reduce({}) do |hash, treatment|
              hash.merge(treatment[:treatment].to_sym => treatment[:config])
            end
          end

          def build_conditions(treatments)
            conditions = treatments.map do |treatment|
              if treatment[:keys]
                build_whitelist_treatment(treatment[:treatment], Array(treatment[:keys]))
              else
                build_rollout_treatment
              end
                .merge(partitions: build_partitions(treatment[:treatment], treatments))
            end

            conditions.sort_by { |condition| condition[:conditionType] }.reverse!
          end

          def build_whitelist_treatment(treatment_name, whitelist_keys)
            {
              conditionType: 'WHITELIST',
              matcherGroup: {
                combiner: 'AND',
                matchers: [{
                  keySelector: nil,
                  matcherType: 'WHITELIST',
                  negate: false,
                  whitelistMatcherData: {
                    whitelist: whitelist_keys
                  }
                }]
              },
              label: "whitelisted #{treatment_name}"
            }
          end

          def build_rollout_treatment
            {
              conditionType: 'ROLLOUT',
              matcherGroup: {
                combiner: 'AND',
                matchers: [
                  {
                    matcherType: 'ALL_KEYS',
                    negate: false
                  }
                ]
              },
              label: 'default rule'
            }
          end

          def build_partitions(current_treatment_name, treatments)
            treatments.map do |treatment|
              {
                treatment: treatment[:treatment],
                size: treatment[:treatment] == current_treatment_name ? 100 : 0
              }
            end
          end
        end
      end
    end
  end
end
