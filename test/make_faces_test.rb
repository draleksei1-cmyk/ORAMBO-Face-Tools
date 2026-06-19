# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../src/orambo_face_tools/make_faces'

module Sketchup
  class Edge; end unless const_defined?(:Edge)
end

class MakeFacesTest < Minitest::Test
  M = ORAMBO::FaceTools::MakeFaces

  class RecordingEntities
    attr_reader :intersect_calls

    def initialize(edges, fail_intersect: false)
      @edges = edges
      @fail_intersect = fail_intersect
      @intersect_calls = 0
    end

    def intersect_with(*_arguments)
      @intersect_calls += 1
      raise 'DWG intersection failed' if @fail_intersect
    end

    def grep(type)
      type == Sketchup::Edge ? @edges : []
    end
  end

  class RecordingReport
    attr_reader :warnings

    def initialize
      @warnings = []
    end

    def warn(message)
      @warnings << message
    end
  end

  def test_gap_pairs_are_nearest_exclusive_and_bounded
    points = [Point.new(0, 0, 0), Point.new(0.5, 0, 0), Point.new(4, 0, 0), Point.new(4.5, 0, 0)]
    pairs, remaining = M.plan_gap_pairs(points, 1.0, 1)
    assert_equal 1, pairs.length
    assert_equal [0, 1], pairs.first.sort
    assert_equal 1, remaining
  end

  def test_large_gap_is_not_closed
    pairs, remaining = M.plan_gap_pairs([Point.new(0, 0, 0), Point.new(5, 0, 0)], 1.0, 10)
    assert_empty pairs
    assert_equal 0, remaining
  end

  def test_zero_gap_disables_gap_closing
    pairs, remaining = M.plan_gap_pairs([Point.new(0, 0, 0), Point.new(0.5, 0, 0)], 0.0, 10)
    assert_empty pairs
    assert_equal 0, remaining
  end

  def test_existing_edge_pair_is_not_closed_again
    points = [Point.new(0, 0, 0), Point.new(0.5, 0, 0)]
    pairs, remaining = M.plan_gap_pairs(points, 1.0, 10, [[0, 1]])
    assert_empty pairs
    assert_equal 0, remaining
  end

  def test_grid_search_does_not_measure_distant_cells
    point_class = Class.new(Point) do
      class << self
        attr_accessor :distance_calls
      end
      def distance(other)
        self.class.distance_calls += 1
        super
      end
    end
    point_class.distance_calls = 0
    points = 200.times.map { |index| point_class.new(index * 10.0, 0, 0) }
    M.plan_gap_pairs(points, 1.0, 10)
    assert_operator point_class.distance_calls, :<, 100
  end

  def test_intersect_edges_uses_entities_and_refreshes_edges
    edge_class = Struct.new(:valid?)
    edges = [edge_class.new(true), edge_class.new(true)]
    entities = RecordingEntities.new(edges)
    report = RecordingReport.new

    result = M.intersect_edges(entities, edges, report, Object.new)

    assert_equal 1, entities.intersect_calls
    assert_equal edges, result
    assert_empty report.warnings
  end

  def test_intersect_failure_becomes_warning_and_returns_current_edges
    edges = [Struct.new(:valid?).new(true)]
    entities = RecordingEntities.new(edges, fail_intersect: true)
    report = RecordingReport.new

    result = M.intersect_edges(entities, edges, report, Object.new)

    assert_equal edges, result
    assert_match(/Пересечения пропущены/, report.warnings.first)
  end
end
