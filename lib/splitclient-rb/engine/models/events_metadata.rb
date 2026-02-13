module SplitIoClient::Engine::Models
    class EventsMetadata
    attr_accessor :type, :names

    def initialize(type, names=nil)
        @type = type
        @names = names
    end
  end
end
