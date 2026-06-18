# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../src/orambo_face_tools/flatten_edges_to_z'

class FlattenEdgesToZTest < Minitest::Test
  F = ORAMBO::FaceTools::FlattenEdgesToZ

  def test_target_world_point_changes_only_z
    point = Point.new(10, -2, 7)
    result = F.target_world_point(point, 0.0)
    assert_equal [10, -2, 0.0], result.to_a
  end

  def test_unique_vertices_deduplicates_by_identity
    vertex = Object.new
    assert_equal [vertex], F.unique_vertices([[vertex, vertex], [vertex]])
  end

  def test_micro_edge_indexes_use_strict_threshold
    assert_equal [0, 2], F.micro_edge_indexes([0.05, 0.1, 0.099], 0.1)
  end

  def test_target_z_modes
    values = [5.0, -2.0, 3.0]
    assert_equal 8.0, F.resolve_target_z('Ручное значение', 8.0, values)
    assert_equal 5.0, F.resolve_target_z('Z первой вершины', 8.0, values)
    assert_equal(-2.0, F.resolve_target_z('Минимальный Z', 8.0, values))
    assert_in_delta 2.0, F.resolve_target_z('Средний Z', 8.0, values), 0.0001
  end

  def test_round_coordinate_uses_requested_precision
    assert_in_delta 1.235, F.round_coordinate(1.2346, 0.001), 0.000001
    assert_equal 1.2346, F.round_coordinate(1.2346, 0.0)
  end
end
