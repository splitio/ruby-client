# frozen_string_literal: true

class MemoryUniqueKeysSenderTest
  attr_reader :bulks
  def initialize
    @bulks = []
  end

  def record_uniques_key(bulk)
    @bulks << bulk
  end

  def record_impressions_count
    # TODO: implementation
  end
end
