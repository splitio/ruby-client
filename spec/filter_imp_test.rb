# frozen_string_literal: true

class FilterTest
  attr_reader :values
  def initialize
    @values = Set.new
  end

  def insert(key)
    @values.add(key)
  end

  def include?(key)
    @values.include?(key)
  end

  def clear
    @values.clear
  end
end
