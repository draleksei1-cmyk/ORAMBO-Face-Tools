# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../src/orambo_face_tools/main'

class CoreTest < Minitest::Test
  def test_identity_and_limits
    assert_equal 'ORAMBO Face Tools', ORAMBO::FaceTools::EXTENSION_NAME
    assert_equal '0.1.2', ORAMBO::FaceTools::EXTENSION_VERSION
    assert_equal 50_000, ORAMBO::FaceTools::MAX_EDGES_NORMAL
    assert_equal 100_000, ORAMBO::FaceTools::MAX_EDGES_HARD
    assert_equal 5_000, ORAMBO::FaceTools::MAX_GAP_CLOSERS
    assert_equal 50, ORAMBO::FaceTools::MAX_EXPLODE_PASSES
    assert_equal 10_000, ORAMBO::FaceTools::MAX_EXPLODE_OBJECTS_PER_PASS
    assert_equal 100_000, ORAMBO::FaceTools::MAX_FIND_FACES_EDGES
    assert_equal 30, ORAMBO::FaceTools::MAX_WARNINGS_SHOWN
    assert_equal 0.001, ORAMBO::FaceTools::ROUNDING_PRECISION_MM
    assert_equal 0.001, ORAMBO::FaceTools::MIN_EDGE_LENGTH_MM
  end
end
