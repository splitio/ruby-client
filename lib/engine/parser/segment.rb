module SplitIoClient

  #
  # acts as dto for a segment structure
  #
  class Segment < NoMethodError
    #
    # definition of the segment
    #
    # @returns [object] segment values
    attr_accessor :data

    #
    # users for the segment
    #
    # @returns [object] array of user keys
    attr_accessor :users

    #
    # added users for the segment in a given time
    #
    # @returns [object] array of user keys that were added after the last segment fetch
    attr_accessor :added

    #
    # removed users for the segment in a given time
    #
    # @returns [object] array of user keys that were removed after the last segment fetch
    attr_accessor :removed

    def initialize(segment)
      @data = segment
      @added = @data[:added]
      @removed = @data[:removed]
    end

    #
    # @returns [string] name of the segment
    def name
      @data[:name]
    end

    #
    # @returns [int] since value fo the segment
    def since
      @data[:since]
    end

    #
    # @returns [int] till value fo the segment
    def till
      @data[:till]
    end

    #
    # @return [boolean] true if the condition is empty false otherwise
    def empty?
      @data.empty?
    end

    def to_h
      {
        name: name,
        since: since,
        till: till
      }
    end

    #
    # updates the array of user keys valid for the segment, it's used after each segment fetch
    #
    # @param added [object] array of added user keys
    # @param removed [object] array of removed user keys
    #
    # @return [void]
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
