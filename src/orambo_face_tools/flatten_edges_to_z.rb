# frozen_string_literal: true

require_relative 'utils'

module ORAMBO
  module FaceTools
    module FlattenEdgesToZ
      module_function

      def target_world_point(point, target_z)
        point.class.new(point.x, point.y, target_z)
      end

      def unique_vertices(edge_vertex_lists)
        seen = {}
        edge_vertex_lists.flatten.each_with_object([]) do |vertex, result|
          key = vertex.object_id
          next if seen[key]
          seen[key] = true
          result << vertex
        end
      end

      def micro_edge_indexes(lengths, threshold)
        lengths.each_with_index.filter_map { |length, index| index if length < threshold }
      end

      def resolve_target_z(mode, manual, world_z_values)
        return manual.to_f if world_z_values.empty?
        case mode
        when 'Z первой вершины' then world_z_values.first.to_f
        when 'Минимальный Z' then world_z_values.map(&:to_f).min
        when 'Средний Z' then world_z_values.sum(&:to_f) / world_z_values.length
        else manual.to_f
        end
      end

      def round_coordinate(value, precision)
        return value if precision.to_f <= 0
        (value.to_f / precision.to_f).round * precision.to_f
      end

      def run
        model = Sketchup.active_model
        return unless Safety.valid_selection(model) && Safety.confirm_large_selection(model.selection)
        defaults = [0.to_l, 'Ручное значение', true, true, true, ORAMBO::FaceTools::ROUNDING_PRECISION_MM.mm,
                    true, ORAMBO::FaceTools::MIN_EDGE_LENGTH_MM.mm, false]
        lists = ['', 'Ручное значение|Z первой вершины|Минимальный Z|Средний Z', '', '', '', '', '', '', '']
        prompts = ['Целевая высота Z:', 'Режим целевой Z:', 'Лезть внутрь групп/компонентов:',
                   'Компоненты делать уникальными:', 'Округлить координаты:', 'Точность округления:',
                   'Проверять микро-рёбра:', 'Минимальная длина edge:', 'Обрабатывать скрытую геометрию:']
        values = UI.inputbox(prompts, defaults, lists, 'Flatten Edges To Z')
        return unless values
        manual_z, mode, deep, make_unique, rounding, precision, check_micro, min_edge, include_hidden = values
        report = Report.new('Flatten Edges To Z завершён')
        selected_container = model.selection.length == 1 ? model.selection.first : nil
        preview_warnings = []
        preview = Utils.collect_edge_contexts(model, model.selection, include_hidden: include_hidden,
                                              make_unique: false, deep: deep, warnings: preview_warnings)
        if preview.empty?
          UI.messagebox('В выделении не найдено доступных рёбер.')
          return
        end
        if preview.any? { |context| Utils.mirrored_transform?(context[:transform]) }
          return unless UI.messagebox('Обнаружен отражённый или отрицательно масштабированный контейнер. Продолжить Flatten?', MB_YESNO) == IDYES
        end
        Safety.with_operation(model, 'ORAMBO Flatten Edges To Z') do
          contexts = Utils.collect_edge_contexts(model, model.selection, include_hidden: include_hidden,
                                                  make_unique: make_unique, deep: deep, warnings: report.warnings)
          raise 'В выделении не найдено рёбер.' if contexts.empty?
          report.increment(:hidden_skipped, report.warnings.count { |text| text.include?('Скрыт') })
          report.increment(:locked_skipped, report.warnings.count { |text| text.include?('Заблокирован') })
          world_z = contexts.flat_map { |context| context[:edges].flat_map(&:vertices).uniq.map { |v| v.position.transform(context[:transform]).z } }
          target_z = resolve_target_z(mode, manual_z.to_f, world_z)
          Progress.start('Flatten Edges To Z', world_z.length)
          contexts.each_with_index do |context, index|
            flatten_context(context, target_z.to_f, rounding ? precision.to_f : 0.0, report)
            Sketchup.status_text = "Flatten Edges To Z: #{index + 1}/#{contexts.length}"
          end
          micro_edges = check_micro ? verify_contexts(contexts, target_z.to_f, min_edge.to_f, report) : []
          if check_micro && micro_edges.any?
            answer = UI.messagebox("После выравнивания найдено микрорёбер: #{micro_edges.length}. Удалить их?", MB_YESNO)
            if answer == IDYES
              micro_edges.each { |edge| edge.erase! if edge.valid? }
              report.increment(:micro_edges_removed, micro_edges.length)
            else
              report.warn('Микрорёбра оставлены пользователем.')
            end
          end
        end
        Utils.select_result(model, selected_container)
        report.show
      rescue StandardError => error
        Safety.handle_failure(report || Report.new('Flatten Edges To Z'), error)
      ensure
        Progress.finish if defined?(Progress)
      end

      def move_vertices(entities, vertices, vectors)
        unless entities.respond_to?(:transform_by_vectors)
          raise ArgumentError, 'Контекст Flatten не содержит Sketchup::Entities.'
        end
        unless vertices.length == vectors.length
          raise ArgumentError, 'Количество вершин и векторов перемещения не совпадает.'
        end

        entities.transform_by_vectors(vertices, vectors) unless vertices.empty?
      end

      def flatten_context(context, target_z, precision, report)
        transform = context[:transform]
        vertices = unique_vertices(context[:edges].map(&:vertices))
        movable, vectors = [], []
        vertices.each do |vertex|
          Progress.tick if defined?(Progress)
          local = vertex.position
          world = local.transform(transform)
          desired_local = Geom::Point3d.new(world.x, world.y, target_z).transform(transform.inverse)
          desired_local = Geom::Point3d.new(round_coordinate(desired_local.x, precision),
                                            round_coordinate(desired_local.y, precision),
                                            round_coordinate(desired_local.z, precision)) if precision.positive?
          vector = desired_local - local
          next if vector.length.zero?
          movable << vertex
          vectors << vector
        rescue StandardError => error
          report.warn("Вершина пропущена: #{error.message}")
        end
        move_vertices(context[:entities], movable, vectors)
        report.increment(:vertices_moved, movable.length)
        report.increment(:edges_processed, context[:edges].length)
      end

      def verify_contexts(contexts, target_z, min_edge_length, report)
        all_micro_edges = []
        contexts.each do |context|
          values = context[:edges].flat_map(&:vertices).uniq.map { |v| v.position.transform(context[:transform]).z }
          spread = Utils.z_spread_values(values)
          tolerance = ORAMBO::FaceTools::COPLANAR_TOLERANCE_MM.mm.to_f
          report.warn("Остаточный разброс Z: #{spread[:spread].to_mm.round(4)} мм") if spread[:spread] > tolerance
          valid_edges = context[:edges].select(&:valid?)
          micro = micro_edge_indexes(valid_edges.map(&:length), min_edge_length)
          all_micro_edges.concat(micro.map { |index| valid_edges[index] })
          report.increment(:micro_edges, micro.length)
        end
        report.add_line("Целевая мировая Z: #{target_z.to_l}")
        all_micro_edges
      end
    end
  end
end
