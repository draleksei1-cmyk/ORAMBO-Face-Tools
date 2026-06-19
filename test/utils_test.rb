# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../src/orambo_face_tools/utils'

class UtilsTest < Minitest::Test
  U = ORAMBO::FaceTools::Utils

  def test_grid_key_handles_negative_coordinates
    assert_equal [-1, 0, 1], U.grid_key(Point.new(-0.1, 0.9, 1.2), 1.0)
  end

  def test_edge_key_is_direction_independent
    a = Point.new(0, 0, 0)
    b = Point.new(2, 1, 0)
    assert_equal U.canonical_edge_key(a, b, 0.001), U.canonical_edge_key(b, a, 0.001)
  end

  def test_z_spread_values
    assert_equal({ min_z: -2.0, max_z: 5.0, spread: 7.0 }, U.z_spread_values([5, -2, 1]))
    assert_equal({ min_z: nil, max_z: nil, spread: 0.0 }, U.z_spread_values([]))
  end

  def test_mirrored_axes
    assert U.mirrored_axes?([1, 0, 0], [0, 1, 0], [0, 0, -1])
    refute U.mirrored_axes?([1, 0, 0], [0, 1, 0], [0, 0, 1])
  end

  def test_detects_hidden_geometry_inside_nested_container
    entity = Struct.new(:hidden?).new(true)
    definition = Struct.new(:entities).new([entity])
    container = Struct.new(:hidden?, :definition).new(false, definition)
    assert U.contains_hidden_geometry?(container)
  end

  def test_entities_for_parent_uses_active_entities_for_model
    active_entities = Object.new
    model = Struct.new(:active_entities).new(active_entities)

    assert_same active_entities, U.entities_for_parent(model, model)
  end

  def test_entities_for_parent_uses_definition_entities
    entities = Object.new
    definition = Struct.new(:entities).new(entities)
    model = Struct.new(:active_entities).new(Object.new)

    assert_same entities, U.entities_for_parent(definition, model)
  end

  def test_entities_for_parent_rejects_unknown_parent
    model = Struct.new(:active_entities).new(Object.new)

    assert_raises(ArgumentError) { U.entities_for_parent(Object.new, model) }
  end
end
