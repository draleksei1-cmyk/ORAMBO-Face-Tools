# frozen_string_literal: true

module ORAMBO
  module FaceTools
    EXTENSION_NAME = 'ORAMBO Face Tools' unless const_defined?(:EXTENSION_NAME)
    EXTENSION_VERSION = '0.1.1' unless const_defined?(:EXTENSION_VERSION)
    MAX_WARNINGS_SHOWN = 30 unless const_defined?(:MAX_WARNINGS_SHOWN)
    MAX_EDGES_NORMAL = 50_000 unless const_defined?(:MAX_EDGES_NORMAL)
    MAX_EDGES_HARD = 100_000 unless const_defined?(:MAX_EDGES_HARD)
    MAX_GAP_CLOSERS = 5_000 unless const_defined?(:MAX_GAP_CLOSERS)
    MAX_EXPLODE_PASSES = 50 unless const_defined?(:MAX_EXPLODE_PASSES)
    MAX_EXPLODE_OBJECTS_PER_PASS = 10_000 unless const_defined?(:MAX_EXPLODE_OBJECTS_PER_PASS)
    MAX_FIND_FACES_EDGES = 100_000 unless const_defined?(:MAX_FIND_FACES_EDGES)
    COPLANAR_TOLERANCE_MM = 0.01 unless const_defined?(:COPLANAR_TOLERANCE_MM)
    ROUNDING_PRECISION_MM = 0.001 unless const_defined?(:ROUNDING_PRECISION_MM)
    MIN_EDGE_LENGTH_MM = 0.001 unless const_defined?(:MIN_EDGE_LENGTH_MM)
    DUPLICATE_EDGE_TOLERANCE_MM = 0.001 unless const_defined?(:DUPLICATE_EDGE_TOLERANCE_MM)
  end
end

if defined?(Sketchup)
  base = __dir__
  %w[utils report progress safety flatten_edges_to_z make_faces break_to_segments diagnostics updater toolbar].each do |file|
    require File.join(base, file)
  end
  ORAMBO::FaceTools::Toolbar.register
  ORAMBO::FaceTools::Updater.schedule_auto_check
end
