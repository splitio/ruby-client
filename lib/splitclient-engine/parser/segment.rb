module SplitIoClient

  class Segment < NoMethodError
    attr_accessor :data
    attr_accessor :users
    attr_accessor :added
    attr_accessor :removed

    def initialize(segment)
      @data = segment
      @added = @data[:added]
      @removed = @data[:removed]
    end

    def name
      @data[:name]
    end

    def since
      @data[:since]
    end

    def till
      @data[:till]
    end

    def is_empty?
      @data.empty? ? true : false
    end

    def refresh_users(added, removed)
      if @users.nil?
        @users = self.added
      else
        @added = added unless added.empty?
        @removed = removed unless removed.empty?
        self.removed.each do |r|
          @users.delete_if { |u| u == r }
        end
        self.added.each do |a|
          @users << a unless @users.include?(a)
        end
      end
    end
  end

end