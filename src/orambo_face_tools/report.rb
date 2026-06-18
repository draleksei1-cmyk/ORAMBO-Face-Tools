# frozen_string_literal: true

module ORAMBO
  module FaceTools
    class Report
      LABELS = {
        edges_processed: 'Рёбер обработано', vertices_moved: 'Вершин перемещено',
        faces_created: 'Новых плоскостей создано', faces_reversed: 'Плоскостей развёрнуто',
        gap_closers: 'Зазоров закрыто', gaps_remaining: 'Зазоров осталось после лимита',
        exploded: 'Объектов взорвано', curves_converted: 'Кривых преобразовано',
        duplicates_removed: 'Дубликатов удалено', hidden_skipped: 'Скрытых объектов пропущено',
        locked_skipped: 'Заблокированных объектов пропущено', micro_edges: 'Микрорёбер найдено',
        micro_edges_removed: 'Микрорёбер удалено', groups_exploded: 'Взорвано групп',
        components_exploded: 'Взорвано компонентов', components_unique: 'Компонентов сделано уникальными',
        open_ends: 'Свободных концов найдено', final_edges: 'Итоговых рёбер'
      }.freeze

      attr_reader :warnings, :title

      def initialize(title)
        @title = title
        @counts = Hash.new(0)
        @warnings = []
        @lines = []
      end

      def increment(key, amount = 1)
        @counts[key] += amount
      end

      def [](key)
        @counts[key]
      end

      def add_line(text)
        @lines << text.to_s
      end

      def warn(message)
        @warnings << message.to_s
      end

      def summary(max_warnings: 30)
        lines = [title]
        @counts.each { |key, value| lines << "#{LABELS.fetch(key, key.to_s)}: #{value}" }
        lines.concat(@lines)
        lines << "Предупреждений: #{warnings.length}"
        lines.concat(warnings.first(max_warnings))
        lines << "Показаны первые #{max_warnings} предупреждений из #{warnings.length}." if warnings.length > max_warnings
        lines.join("\n")
      end

      def show
        puts("[ORAMBO Face Tools] #{title}")
        warnings.each { |message| puts("  WARNING: #{message}") }
        UI.messagebox(summary(max_warnings: ORAMBO::FaceTools::MAX_WARNINGS_SHOWN))
      end
    end
  end
end
