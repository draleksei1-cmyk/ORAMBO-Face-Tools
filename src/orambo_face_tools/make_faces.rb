# frozen_string_literal: true

require_relative 'utils'

module ORAMBO
  module FaceTools
    module MakeFaces
      GAP_TAG = 'ORAMBO_Gap_Closers'
      module_function

      def plan_gap_pairs(points, max_distance, limit, blocked_pairs = [])
        return [[], 0] unless max_distance.to_f.positive? && limit.to_i.positive?
        blocked = {}
        blocked_pairs.each { |left, right| blocked[[left, right].sort] = true }
        buckets = Hash.new { |hash, key| hash[key] = [] }
        candidates = []
        points.each_with_index do |point, right|
          key = Utils.grid_key(point, max_distance)
          (-1..1).each do |dx|
            (-1..1).each do |dy|
              (-1..1).each do |dz|
                buckets[[key[0] + dx, key[1] + dy, key[2] + dz]].each do |left|
                  next if blocked[[left, right].sort]
                  distance = point.distance(points[left])
                  candidates << [distance, left, right] if distance.positive? && distance <= max_distance
                end
              end
            end
          end
          buckets[key] << right
        end
        used = {}
        possible = candidates.sort_by { |item| [item[0], item[1], item[2]] }.each_with_object([]) do |(_, left, right), pairs|
          next if used[left] || used[right]
          used[left] = used[right] = true
          pairs << [left, right]
        end
        [possible.first(limit), [possible.length - limit, 0].max]
      end

      def run
        model = Sketchup.active_model
        return unless Safety.valid_selection(model) && Safety.confirm_large_selection(model.selection)
        defaults = [1.mm, ORAMBO::FaceTools::MAX_GAP_CLOSERS, false, true,
                    ORAMBO::FaceTools::COPLANAR_TOLERANCE_MM.mm, true, 'К камере', false, false]
        lists = ['', '', '', '', '', '', 'Не трогать|К камере|Вверх по Z', '', '']
        prompts = ['Замыкать зазоры до:', 'Максимум замыкающих линий:', 'Разбить пересечения линий:',
                   'Проверять плоскостность:', 'Допуск плоскостности по Z:', 'Лезть внутрь групп/компонентов:',
                   'Ориентация новых плоскостей:', 'Развернуть существующие плоскости:', 'Обрабатывать скрытую геометрию:']
        values = UI.inputbox(prompts, defaults, lists, 'Make Faces')
        return unless values
        gap, max_closers, intersect, check_coplanar, coplanar_tolerance, deep,
          orientation, orient_existing, include_hidden = values
        max_closers = [[max_closers.to_i, 0].max, ORAMBO::FaceTools::MAX_GAP_CLOSERS].min
        if intersect
          warning = 'Разбиение пересечений может порезать дуги и кривые. Продолжить?'
          return unless UI.messagebox(warning, MB_YESNO) == IDYES
        end
        report = Report.new('Make Faces завершён')
        selected_container = model.selection.length == 1 ? model.selection.first : nil
        preview_warnings = []
        preview = Utils.collect_edge_contexts(model, model.selection, include_hidden: include_hidden,
                                              make_unique: false, deep: deep, warnings: preview_warnings)
        if preview.empty?
          UI.messagebox('В выделении не найдено доступных рёбер.')
          return
        end
        if preview.any? { |context| context[:edges].length > ORAMBO::FaceTools::MAX_FIND_FACES_EDGES }
          UI.messagebox('В одном контексте больше 100 000 рёбер. Обработайте участок частями.')
          return
        end
        if preview.any? { |context| Utils.mirrored_transform?(context[:transform]) }
          return unless UI.messagebox('Обнаружен отражённый или отрицательно масштабированный контейнер. Продолжить Make Faces?', MB_YESNO) == IDYES
        end
        if check_coplanar
          worst = preview.map { |context| context_z_spread(context) }.max.to_f
          if worst > coplanar_tolerance.to_f
            message = "Выбранные линии не лежат в одной Z-плоскости.\n\nРазброс Z: #{worst.to_mm.round(3)} мм.\nРекомендуется сначала нажать Flatten Edges To Z.\n\nПродолжить?"
            return unless UI.messagebox(message, MB_YESNO) == IDYES
          end
          report.add_line("Разброс Z до Make Faces: #{worst.to_mm.round(4)} мм")
        end
        Safety.with_operation(model, 'ORAMBO Make Faces') do
          contexts = Utils.collect_edge_contexts(model, model.selection, include_hidden: include_hidden,
                                                  make_unique: true, deep: deep, warnings: report.warnings)
          raise 'В выделении не найдено рёбер.' if contexts.empty?
          report.increment(:hidden_skipped, report.warnings.count { |text| text.include?('Скрыт') })
          report.increment(:locked_skipped, report.warnings.count { |text| text.include?('Заблокирован') })
          Progress.start('Make Faces', contexts.sum { |context| context[:edges].length })
          contexts.each_with_index do |context, index|
            process_context(model, context, gap.to_f, max_closers, intersect, orientation, orient_existing, report)
            Sketchup.status_text = "Make Faces: #{index + 1}/#{contexts.length}"
          end
        end
        Utils.select_result(model, selected_container)
        report.show
      rescue StandardError => error
        Safety.handle_failure(report || Report.new('Make Faces'), error)
      ensure
        Progress.finish if defined?(Progress)
      end

      def context_z_spread(context)
        world_z = context[:edges].flat_map(&:vertices).uniq.map { |v| v.position.transform(context[:transform]).z }
        Utils.z_spread_values(world_z)[:spread]
      end

      def intersect_edges(entities, edges, report, identity = nil)
        identity ||= Geom::Transformation.new
        entities.intersect_with(false, identity, entities, identity, false, edges)
        entities.grep(Sketchup::Edge).select(&:valid?)
      rescue StandardError => error
        report.warn("Пересечения пропущены: #{error.message}")
        entities.grep(Sketchup::Edge).select(&:valid?)
      end

      def process_context(model, context, gap, max_closers, intersect, orientation, orient_existing, report)
        entities = context[:entities]
        edges = context[:edges].select(&:valid?)
        faces_before = entities.grep(Sketchup::Face).select(&:valid?).map(&:object_id)
        edges = intersect_edges(entities, edges, report) if intersect && edges.length > 1
        degree = Hash.new(0)
        edges.each { |edge| edge.vertices.each { |vertex| degree[vertex] += 1 } }
        open_vertices = degree.select { |_, value| value == 1 }.keys
        local_points = open_vertices.map(&:position)
        world_points = local_points.map { |point| point.transform(context[:transform]) }
        index_by_vertex = {}
        open_vertices.each_with_index { |vertex, index| index_by_vertex[vertex.object_id] = index }
        blocked = edges.filter_map do |edge|
          left = index_by_vertex[edge.start.object_id]
          right = index_by_vertex[edge.end.object_id]
          [left, right] if left && right
        end
        pairs, _remaining_pairs = plan_gap_pairs(world_points, gap, max_closers, blocked)
        remaining = [open_vertices.length - pairs.length * 2, 0].max
        tag = model.layers[GAP_TAG] || model.layers.add(GAP_TAG)
        closing_edges = pairs.filter_map do |left, right|
          edge = entities.add_line(local_points[left], local_points[right])
          edge.layer = tag if edge
          edge
        rescue StandardError => error
          report.warn("Зазор не закрыт: #{error.message}")
          nil
        end
        report.increment(:gap_closers, pairs.length)
        report.increment(:gaps_remaining, remaining)
        report.increment(:open_ends, open_vertices.length)
        if pairs.length >= max_closers && remaining.positive?
          report.warn("Достигнут лимит замыкающих линий. Создано: #{pairs.length}. Осталось свободных концов: #{remaining}.")
        end
        edges = entities.grep(Sketchup::Edge).select(&:valid?)
        (edges + closing_edges).uniq.each do |edge|
          Progress.tick if defined?(Progress)
          edge.find_faces if edge && edge.valid?
        rescue StandardError => error
          report.warn("Ребро не обработано find_faces: #{error.message}")
        end
        new_faces = entities.grep(Sketchup::Face).select(&:valid?).reject { |face| faces_before.include?(face.object_id) }
        faces_to_orient = orient_existing ? entities.grep(Sketchup::Face).select(&:valid?) : new_faces
        faces_to_orient.each { |face| orient_face(model, face, context[:transform], orientation, report) } unless orientation == 'Не трогать'
        report.increment(:faces_created, new_faces.length)
        if new_faces.empty?
          report.warn('Грани не созданы. Возможные причины: незамкнутые контуры, разные группы, неплоская геометрия, дубли или микрорёбра.')
        end
      end

      def orient_face(model, face, transform, orientation, report)
        normal = face.normal.transform(transform)
        reverse = if orientation == 'Вверх по Z'
                    normal.z.negative?
                  else
                    normal.dot(model.active_view.camera.direction).positive?
                  end
        if reverse
          face.reverse!
          report.increment(:faces_reversed)
        end
      rescue StandardError => error
        report.warn("Грань не развёрнута: #{error.message}")
      end
    end
  end
end
