# frozen_string_literal: true

require 'minitest/autorun'

Point = Struct.new(:x, :y, :z) do
  def distance(other)
    Math.sqrt((x - other.x)**2 + (y - other.y)**2 + (z - other.z)**2)
  end

  def to_a
    [x, y, z]
  end
end

class RecordingModel
  attr_reader :events

  def initialize
    @events = []
  end

  def start_operation(name, disable_ui = true)
    @events << [:start, name, disable_ui]
  end

  def commit_operation
    @events << [:commit]
  end

  def abort_operation
    @events << [:abort]
  end
end
