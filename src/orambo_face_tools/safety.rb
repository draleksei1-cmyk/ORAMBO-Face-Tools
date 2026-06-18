# frozen_string_literal: true

require_relative 'utils'

module ORAMBO
  module FaceTools
    module Safety
      module_function

      def with_operation(model, name)
        model.start_operation(name, true)
        result = yield
        model.commit_operation
        result
      rescue Exception
        model.abort_operation
        raise
      end

      def valid_selection(model)
        unless model && model.selection && !model.selection.empty?
          UI.messagebox('Выберите рёбра, группу или компонент.') if defined?(UI)
          return false
        end
        true
      end

      def confirm_large_selection(selection)
        count = Utils.count_edges_in_selection(selection, deep: true)
        return true if count <= ORAMBO::FaceTools::MAX_EDGES_NORMAL
        message = if count > ORAMBO::FaceTools::MAX_EDGES_HARD
                    "Выбрано больше 100 000 линий. SketchUp может надолго зависнуть.\n\nЛучше обработать участок частями.\n\nПродолжить всё равно?"
                  else
                    "Выбрано очень много линий. Операция может занять несколько минут или повесить SketchUp.\n\nРекомендуется обработать генплан частями.\n\nПродолжить?"
                  end
        UI.messagebox(message, MB_YESNO) == IDYES
      end

      def handle_failure(report, error)
        report.warn("Критическая ошибка: #{error.class}: #{error.message}")
        puts(error.full_message) if error.respond_to?(:full_message)
        report.show
      end
    end
  end
end
