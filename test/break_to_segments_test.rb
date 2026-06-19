# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../src/orambo_face_tools/break_to_segments'

class BreakToSegmentsTest < Minitest::Test
  B = ORAMBO::FaceTools::BreakToSegments

  class RecordingReport
    attr_reader :increments, :warnings

    def initialize
      @increments = Hash.new(0)
      @warnings = []
    end

    def increment(key, amount = 1)
      @increments[key] += amount
    end

    def warn(message)
      @warnings << message
    end
  end

  class ExplodableEdge
    attr_accessor :curve
    attr_reader :explode_calls

    def initialize(hidden: false)
      @hidden = hidden
      @explode_calls = 0
    end

    def hidden?
      @hidden
    end

    def valid?
      true
    end

    def explode_curve
      @explode_calls += 1
      self
    end
  end

  def test_duplicate_indexes_keep_first_edge_regardless_of_direction
    edges = [
      [Point.new(0, 0, 0), Point.new(1, 0, 0)],
      [Point.new(1, 0, 0), Point.new(0, 0, 0)],
      [Point.new(0, 0, 0), Point.new(2, 0, 0)]
    ]
    assert_equal [1], B.duplicate_indexes(edges, 0.001)
  end

  def test_explode_passes_are_bounded
    assert_equal 8, B.bounded_passes(20, 8)
    assert_equal 3, B.bounded_passes(3, 8)
  end

  def test_curve_conversion_is_enabled_by_default
    assert_equal true, B::DEFAULT_CONVERT_CURVES
  end

  def test_convert_curves_uses_native_explode_once_per_curve
    first = ExplodableEdge.new
    second = ExplodableEdge.new
    curve = Struct.new(:edges).new([first, second])
    first.curve = curve
    second.curve = curve
    report = RecordingReport.new

    B.convert_curves(Object.new, [first, second], false, report)

    assert_equal 1, first.explode_calls + second.explode_calls
    assert_equal 1, report.increments[:curves_converted]
    assert_empty report.warnings
  end

  def test_convert_curves_skips_hidden_curve_unless_requested
    edge = ExplodableEdge.new(hidden: true)
    curve = Struct.new(:edges).new([edge])
    edge.curve = curve
    report = RecordingReport.new

    B.convert_curves(Object.new, [edge], false, report)

    assert_equal 0, edge.explode_calls
    assert_equal 0, report.increments[:curves_converted]
  end
end
