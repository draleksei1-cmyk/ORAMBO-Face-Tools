# frozen_string_literal: true

require_relative 'utils'

module ORAMBO
  module FaceTools
    module BreakToSegments
      DEFAULT_CONVERT_CURVES = true
      module_function

      def duplicate_indexes(edge_points, tolerance)
        seen = {}
        edge_points.each_with_index.each_with_object([]) do |((point_a, point_b), index), duplicates|
          key = Utils.canonical_edge_key(point_a, point_b, tolerance)
          seen.key?(key) ? duplicates << index : seen[key] = index
        end
      end

      def bounded_passes(requested, maximum)
        [[requested.to_i, 0].max, maximum.to_i].min
      end

      def run
        model = Sketchup.active_model
        return unless Safety.valid_selection(model) && Safety.confirm_large_selection(model.selection)
        warning = "Операция разрушительная.\n\nОна может взорвать группы, компоненты, дуги и кривые до простых отрезков.\n\nЛучше сохранить копию файла перед запуском.\n\nПродолжить?"
        return unless UI.messagebox(warning, MB_YESNO) == IDYES
        defaults = [true, true, true, DEFAULT_CONVERT_CURVES, false,
                    ORAMBO::FaceTools::DUPLICATE_EDGE_TOLERANCE_MM.mm, false]
        prompts = ['Несколько объектов собрать в группу:', 'Взрывать вложенные группы:',
                   'Взрывать вложенные компоненты:', 'Кривые и дуги перевести в отрезки:',
                   'Удалить дублирующиеся отрезки:', 'Tolerance для дублей:', 'Обрабатывать скрытую геометрию:']
        values = UI.inputbox(prompts, defaults, 'Break To Segments')
        return unless values
        group_selection, explode_groups, explode_components, convert, remove_dupes, tolerance, include_hidden = values
        if remove_dupes
          return unless UI.messagebox('Удаление дублей может удалить линии с разных DWG-слоёв. Продолжить?', MB_YESNO) == IDYES
        end
        report = Report.new('Break To Segments завершён')
        work_group = nil
        Safety.with_operation(model, 'ORAMBO Break To Segments') do
          targets, direct_edges, work_group = create_work_targets(model, group_selection, report)
          raise 'В выделении нет доступных рёбер, групп или компонентов.' if targets.empty? && direct_edges.empty?
          targets.each do |target|
            explode_nested(target, explode_groups, explode_components, include_hidden, report)
            convert_curves(target.definition.entities, nil, include_hidden, report) if convert
            remove_duplicates(target.definition.entities, nil, include_hidden, tolerance.to_f, report) if remove_dupes
          end
          convert_curves(model.active_entities, direct_edges, include_hidden, report) if convert && direct_edges.any?
          remove_duplicates(model.active_entities, direct_edges, include_hidden, tolerance.to_f, report) if remove_dupes && direct_edges.any?
          report.increment(:final_edges, targets.sum { |target| target.definition.entities.grep(Sketchup::Edge).length } + direct_edges.count(&:valid?))
        end
        Utils.select_result(model, work_group)
        report.show
      rescue StandardError => error
        Safety.handle_failure(report || Report.new('Break To Segments'), error)
      ensure
        Progress.finish if defined?(Progress)
      end

      def create_work_targets(model, group_selection, report)
        selected = model.selection.to_a
        if selected.length > 1 && group_selection
          group = model.active_entities.add_group(selected)
          raise 'Не удалось создать рабочую группу.' unless group && group.valid?
          group.name = 'ORAMBO_Broken_Segments'
          report.add_line('Создана рабочая группа: да')
          [[group], [], group]
        else
          targets = selected.select { |entity| Utils.container?(entity) }
          targets.select! do |target|
            next true unless Utils.mirrored_transform?(target.transformation)
            UI.messagebox('Обнаружен отражённый компонент. Продолжить обработку?', MB_YESNO) == IDYES
          end
          targets.each do |target|
            if target.is_a?(Sketchup::ComponentInstance) && !target.is_a?(Sketchup::Group)
              target.make_unique
              report.increment(:components_unique)
            end
          end
          direct_edges = selected.grep(Sketchup::Edge)
          report.add_line('Создана рабочая группа: нет')
          [targets, direct_edges, targets.length == 1 ? targets.first : nil]
        end
      end

      def explode_nested(container, explode_groups, explode_components, include_hidden, report)
        completed = false
        ORAMBO::FaceTools::MAX_EXPLODE_PASSES.times do |pass|
          entities = container.definition.entities
          groups = explode_groups ? entities.grep(Sketchup::Group) : []
          components = explode_components ? entities.grep(Sketchup::ComponentInstance).reject { |item| item.is_a?(Sketchup::Group) } : []
          containers = (groups + components).first(ORAMBO::FaceTools::MAX_EXPLODE_OBJECTS_PER_PASS)
          containers.select! do |item|
            if item.locked?
              report.increment(:locked_skipped)
              false
            elsif item.hidden? && !include_hidden
              report.increment(:hidden_skipped)
              false
            elsif !include_hidden && Utils.contains_hidden_geometry?(item)
              report.increment(:hidden_skipped)
              report.warn('Вложенный объект со скрытой геометрией не взорван.')
              false
            else
              true
            end
          end
          if containers.empty?
            completed = true
            break
          end
          Progress.start('Break To Segments', containers.length) if pass.zero? && defined?(Progress)
          containers.each do |container|
            if Utils.mirrored_transform?(container.transformation)
              answer = UI.messagebox('Обнаружен отражённый компонент. Продолжить explode?', MB_YESNO)
              next unless answer == IDYES
            end
            component = container.is_a?(Sketchup::ComponentInstance) && !container.is_a?(Sketchup::Group)
            if component
              container.make_unique
              report.increment(:components_unique)
            end
            was_hidden = container.hidden?
            exploded_entities = container.explode
            if include_hidden && was_hidden
              exploded_entities.each { |entity| entity.hidden = true if entity.respond_to?(:hidden=) }
            end
            Progress.tick if defined?(Progress)
            report.increment(:exploded)
            report.increment(component ? :components_exploded : :groups_exploded)
          rescue StandardError => error
            report.warn("Объект не взорван: #{error.message}")
          end
          Sketchup.status_text = "Break To Segments: проход #{pass + 1}/#{ORAMBO::FaceTools::MAX_EXPLODE_PASSES}"
        end
        entities = container.definition.entities
        remains = entities.grep(Sketchup::Group).length + entities.grep(Sketchup::ComponentInstance).reject { |item| item.is_a?(Sketchup::Group) }.length
        report.warn("Достигнут лимит проходов explode. Осталось вложенных объектов: #{remains}") if !completed && remains.positive?
      end

      def convert_curves(entities, allowed_edges, include_hidden, report)
        source = allowed_edges || entities.grep(Sketchup::Edge)
        curves = source.map(&:curve).compact.uniq
        curves.reject! { |curve| curve.edges.any?(&:hidden?) } unless include_hidden
        curves.each do |curve|
          edge = curve.edges.find(&:valid?)
          next unless edge

          exploded = edge.explode_curve
          raise 'SketchUp не разорвал связь Curve/Arc.' unless exploded

          report.increment(:curves_converted)
        rescue StandardError => error
          report.warn("Кривая не преобразована: #{error.message}")
        end
      end

      def remove_duplicates(entities, allowed_edges, include_hidden, tolerance, report)
        edges = (allowed_edges || entities.grep(Sketchup::Edge)).select { |edge| edge.valid? && (include_hidden || !edge.hidden?) }
        indexes = duplicate_indexes(edges.map { |edge| [edge.start.position, edge.end.position] }, tolerance)
        indexes.reverse_each do |index|
          edges[index].erase! if edges[index].valid?
          report.increment(:duplicates_removed)
        rescue StandardError => error
          report.warn("Дубликат не удалён: #{error.message}")
        end
      end
    end
  end
end
