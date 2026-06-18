# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../src/orambo_face_tools/report'

class ReportTest < Minitest::Test
  def test_counts_and_bounded_warning_summary
    report = ORAMBO::FaceTools::Report.new('Проверка')
    report.increment(:faces_created, 2)
    35.times { |index| report.warn("Ошибка #{index + 1}") }
    text = report.summary(max_warnings: 30)

    assert_equal 2, report[:faces_created]
    assert_includes text, 'Предупреждений: 35'
    assert_includes text, 'Показаны первые 30 предупреждений из 35.'
    refute_includes text, 'Ошибка 31'
  end
end
