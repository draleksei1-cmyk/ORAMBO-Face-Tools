# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../src/orambo_face_tools/diagnostics'

module Sketchup
  class Group; end unless const_defined?(:Group)
end

class DiagnosticsTest < Minitest::Test
  D = ORAMBO::FaceTools::Diagnostics

  class FakeGroup < Sketchup::Group
    attr_accessor :name
    attr_reader :erased

    def initialize(name)
      @name = name
      @erased = false
    end

    def valid?
      !@erased
    end

    def erase!
      @erased = true
    end
  end

  class FakeEntities
    attr_reader :groups

    def initialize(groups)
      @groups = groups
    end

    def grep(type)
      type == Sketchup::Group ? @groups : []
    end

    def add_group
      group = FakeGroup.new(nil)
      @groups << group
      group
    end
  end

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

  def test_cross_segments_create_two_diagonals_around_center
    center = Point.new(10, 20, 0)

    segments = D.cross_segments(center, 2)

    assert_equal [
      [[8, 18, 0], [12, 22, 0]],
      [[8, 22, 0], [12, 18, 0]]
    ], segments.map { |segment| segment.map(&:to_a) }
  end

  def test_gap_segments_follow_planned_pairs
    points = [Point.new(0, 0, 0), Point.new(1, 0, 0), Point.new(5, 0, 0)]

    segments = D.gap_segments(points, [[0, 1]])

    assert_equal [[[0, 0, 0], [1, 0, 0]]], segments.map { |segment| segment.map(&:to_a) }
  end

  def test_replace_marker_group_removes_only_matching_group
    open_group = FakeGroup.new(D::OPEN_ENDS_GROUP)
    gaps_group = FakeGroup.new(D::GAPS_GROUP)
    entities = FakeEntities.new([open_group, gaps_group])

    replacement = D.replace_marker_group(entities, D::OPEN_ENDS_GROUP)

    assert open_group.erased
    refute gaps_group.erased
    assert_equal D::OPEN_ENDS_GROUP, replacement.name
  end
end
