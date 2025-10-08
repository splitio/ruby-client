module SplitIoClient::Engine::Models
    class FallbackTreatment
    attr_accessor :treatment, :config, :label

    def initialize(treatment, config=nil, label=nil)
        @treatment = treatment
        @config = config
        @label = label
    end
  end
end
