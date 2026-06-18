# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../src/orambo_face_tools/break_to_segments'

class BreakToSegmentsTest < Minitest::Test
  B = ORAMBO::FaceTools::BreakToSegments

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
end
