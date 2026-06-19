# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../src/orambo_face_tools/diagnostics'

class DiagnosticsTest < Minitest::Test
  D = ORAMBO::FaceTools::Diagnostics

  def test_open_vertex_indexes_find_chain_ends
    assert_equal [0, 2], D.open_vertex_indexes([[0, 1], [1, 2]])
  end

  def test_closed_loop_has_no_open_ends
    edges = [[0, 1], [1, 2], [2, 3], [3, 0]]

    assert_empty D.open_vertex_indexes(edges)
  end

  def test_gap_pairs_choose_nearest_exclusive_pairs
    points = [Point.new(0, 0, 0), Point.new(0.4, 0, 0), Point.new(4, 0, 0), Point.new(4.5, 0, 0)]

    pairs, unpaired = D.plan_gap_pairs(points, [0, 1, 2, 3], 1.0)

    assert_equal [[0, 1], [2, 3]], pairs
    assert_empty unpaired
  end

  def test_gap_pairs_respect_distance_and_existing_edges
    points = [Point.new(0, 0, 0), Point.new(0.5, 0, 0), Point.new(5, 0, 0)]

    pairs, unpaired = D.plan_gap_pairs(points, [0, 1, 2], 1.0, [[0, 1]])

    assert_empty pairs
    assert_equal [0, 1, 2], unpaired
  end

  def test_marker_half_size_is_scaled_and_clamped
    assert_in_delta D::MIN_MARKER_HALF_SIZE, D.marker_half_size(1.0), 0.000001
    assert_in_delta 2.0, D.marker_half_size(1000.0), 0.000001
    assert_in_delta D::MAX_MARKER_HALF_SIZE, D.marker_half_size(1_000_000.0), 0.000001
  end
end
