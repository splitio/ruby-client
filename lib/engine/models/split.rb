module SplitIoClient
  module Engine
    module Models
      class Split
        class << self
          def matchable?(data)
            data && data[:status] == 'ACTIVE' && data[:killed] == false
          end

          def archived?(data)
            data && data[:status] == 'ARCHIVED'
          end
        end
      end
    end
  end
end
