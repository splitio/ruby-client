# frozen_string_literal: true

class FilterTest
  attr_reader :values
  def initialize
    @values = Set.new
  end

  def add(key)
    @values.add(key)
  end

  def contains?(key)
    @values.include?(key)
  end

  def clear
    @values.clear
  end
end
