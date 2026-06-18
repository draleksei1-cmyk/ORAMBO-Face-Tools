# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../src/orambo_face_tools/safety'

class SafetyTest < Minitest::Test
  def test_commits_successful_operation
    model = RecordingModel.new
    result = ORAMBO::FaceTools::Safety.with_operation(model, 'Test') { 42 }
    assert_equal 42, result
    assert_equal [[:start, 'Test', true], [:commit]], model.events
  end

  def test_aborts_failed_operation
    model = RecordingModel.new
    assert_raises(RuntimeError) do
      ORAMBO::FaceTools::Safety.with_operation(model, 'Test') { raise 'boom' }
    end
    assert_equal [[:start, 'Test', true], [:abort]], model.events
  end
end
