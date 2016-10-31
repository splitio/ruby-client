module SplitIoClient
  module Engine
    module Models
      class Split
        def initialize(data)
          @data = data
        end

        def matchable?
          @data && @data[:status] == 'ACTIVE' && @data[:killed] == false
        end

        def archived?
          @data && @data[:status] == 'ARCHIVED'
        end
      end
    end
  end
end
