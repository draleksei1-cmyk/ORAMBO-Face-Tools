# frozen_string_literal: true

require_relative 'utils'

module ORAMBO
  module FaceTools
    module Diagnostics
      OPEN_ENDS_GROUP = 'ORAMBO_Open_Ends'
      GAPS_GROUP = 'ORAMBO_Gaps'
      DIAGNOSTICS_TAG = 'ORAMBO_Diagnostics'
      DIAGNOSTICS_MATERIAL = 'ORAMBO_Diagnostics_Red'
      MIN_MARKER_HALF_SIZE = 10.0 / 25.4
      MAX_MARKER_HALF_SIZE = 500.0 / 25.4
      module_function

      def open_vertex_indexes(edge_pairs)
        degree = Hash.new(0)
        edge_pairs.each do |left, right|
          degree[left] += 1
          degree[right] += 1
        end
        degree.select { |_, count| count == 1 }.keys.sort
      end

      def plan_gap_pairs(points, open_indexes, max_distance, blocked_pairs = [])
        distance_limit = max_distance.to_f
        indexes = open_indexes.uniq.sort
        return [[], indexes] unless distance_limit.positive?

        blocked = {}
        blocked_pairs.each { |left, right| blocked[[left, right].sort] = true }
        buckets = Hash.new { |hash, key| hash[key] = [] }
        candidates = []
        indexes.each do |right|
          point = points.fetch(right)
          key = Utils.grid_key(point, distance_limit)
          (-1..1).each do |dx|
            (-1..1).each do |dy|
              (-1..1).each do |dz|
                buckets[[key[0] + dx, key[1] + dy, key[2] + dz]].each do |left|
                  next if blocked[[left, right].sort]

                  distance = point.distance(points.fetch(left))
                  candidates << [distance, left, right] if distance.positive? && distance <= distance_limit
                end
              end
            end
          end
          buckets[key] << right
        end

        used = {}
        pairs = candidates.sort_by { |distance, left, right| [distance, left, right] }.filter_map do |_, left, right|
          next if used[left] || used[right]

          used[left] = used[right] = true
          [left, right]
        end
        [pairs, indexes.reject { |index| used[index] }]
      end

      def marker_half_size(bounds_diagonal)
        [[bounds_diagonal.to_f * 0.002, MIN_MARKER_HALF_SIZE].max, MAX_MARKER_HALF_SIZE].min
      end

      def cross_segments(center, half_size)
        point = lambda do |x, y, z|
          center.class.new(x, y, z)
        end
        x, y, z = center.x, center.y, center.z
        [
          [point.call(x - half_size, y - half_size, z), point.call(x + half_size, y + half_size, z)],
          [point.call(x - half_size, y + half_size, z), point.call(x + half_size, y - half_size, z)]
        ]
      end

      def gap_segments(points, pairs)
        pairs.map { |left, right| [points.fetch(left), points.fetch(right)] }
      end

      def replace_marker_group(entities, name)
        entities.grep(Sketchup::Group).each do |group|
          group.erase! if group.valid? && group.name == name
        end
        group = entities.add_group
        group.name = name
        group
      end

      def context_data(context)
        vertices = []
        indexes = {}
        edges = context[:edges].select(&:valid?)
        edge_pairs = edges.map do |edge|
          edge.vertices.map do |vertex|
            indexes[vertex.object_id] ||= begin
              vertices << vertex
              vertices.length - 1
            end
          end
        end
        points = vertices.map { |vertex| vertex.position.transform(context[:transform]) }
        { vertices: vertices, points: points, edge_pairs: edge_pairs, edges: edges }
      end

      def bounds_diagonal(points)
        return 0.0 if points.empty?

        xs = points.map { |point| point.x.to_f }
        ys = points.map { |point| point.y.to_f }
        zs = points.map { |point| point.z.to_f }
        Math.sqrt((xs.max - xs.min)**2 + (ys.max - ys.min)**2 + (zs.max - zs.min)**2)
      end

      def run_open_ends
        model = Sketchup.active_model
        return unless Safety.valid_selection(model) && Safety.confirm_large_selection(model.selection)

        report = Report.new('Select Open Ends завершён')
        segments = []
        problem_edges = []
        Safety.with_operation(model, 'ORAMBO Select Open Ends') do
          contexts = Utils.collect_edge_contexts(model, model.selection, deep: true, warnings: report.warnings)
          raise 'В выделении не найдено рёбер.' if contexts.empty?

          all_points = contexts.flat_map { |context| context_data(context)[:points] }
          half_size = marker_half_size(bounds_diagonal(all_points))
          contexts.each do |context|
            data = context_data(context)
            open_indexes = open_vertex_indexes(data[:edge_pairs])
            open_lookup = open_indexes.each_with_object({}) { |index, hash| hash[index] = true }
            segments.concat(open_indexes.flat_map { |index| cross_segments(data[:points][index], half_size) })
            data[:edge_pairs].each_with_index do |(left, right), edge_index|
              problem_edges << data[:edges][edge_index] if open_lookup[left] || open_lookup[right]
            end
            report.increment(:open_ends, open_indexes.length)
          end
          create_marker_group(model, OPEN_ENDS_GROUP, segments)
        end
        select_edges(model, problem_edges)
        report.show
      rescue StandardError => error
        Safety.handle_failure(report || Report.new('Select Open Ends'), error)
      end

      def run_highlight_gaps
        model = Sketchup.active_model
        return unless Safety.valid_selection(model) && Safety.confirm_large_selection(model.selection)

        values = UI.inputbox(['Показывать зазоры до:'], [10.mm], 'Highlight Gaps')
        return unless values
        max_distance = values.first.to_f
        report = Report.new('Highlight Gaps завершён')
        segments = []
        Safety.with_operation(model, 'ORAMBO Highlight Gaps') do
          contexts = Utils.collect_edge_contexts(model, model.selection, deep: true, warnings: report.warnings)
          raise 'В выделении не найдено рёбер.' if contexts.empty?

          contexts.each do |context|
            data = context_data(context)
            open_indexes = open_vertex_indexes(data[:edge_pairs])
            pairs, unpaired = plan_gap_pairs(data[:points], open_indexes, max_distance, data[:edge_pairs])
            segments.concat(gap_segments(data[:points], pairs))
            report.increment(:gap_pairs, pairs.length)
            report.increment(:unpaired_ends, unpaired.length)
          end
          create_marker_group(model, GAPS_GROUP, segments)
        end
        report.show
      rescue StandardError => error
        Safety.handle_failure(report || Report.new('Highlight Gaps'), error)
      end

      def create_marker_group(model, name, world_segments)
        active_transform = Utils.active_context_transform(model)
        to_active = active_transform.inverse
        group = replace_marker_group(model.active_entities, name)
        group.layer = model.layers[DIAGNOSTICS_TAG] || model.layers.add(DIAGNOSTICS_TAG)
        material = model.materials[DIAGNOSTICS_MATERIAL] || model.materials.add(DIAGNOSTICS_MATERIAL)
        material.color = Sketchup::Color.new(230, 35, 35)
        group.material = material
        world_segments.each do |start_point, end_point|
          edge = group.entities.add_line(start_point.transform(to_active), end_point.transform(to_active))
          edge.material = material if edge
        end
        group
      end

      def select_edges(model, edges)
        model.selection.clear
        edges.uniq.each { |edge| model.selection.add(edge) if edge.valid? }
      rescue StandardError
        nil
      end

      def register_hot_commands
        return false unless defined?(ORAMBO::FaceTools::Toolbar)
        return true if @hot_commands_registered

        toolbar = ORAMBO::FaceTools::Toolbar.instance_variable_get(:@toolbar)
        return false unless toolbar

        definitions = [
          ['Select Open Ends', 'open_ends', 'Показать свободные концы красными крестиками', -> { run_open_ends }],
          ['Highlight Gaps', 'highlight_gaps', 'Показать ближайшие разрывы между контурами', -> { run_highlight_gaps }]
        ]
        definitions.each do |label, icon_name, help, action|
          command = UI::Command.new(label, &action)
          command.tooltip = label
          command.status_bar_text = help
          icon_dir = File.join(__dir__, 'icons')
          small = File.join(icon_dir, "#{icon_name}_16.png")
          large = File.join(icon_dir, "#{icon_name}_24.png")
          command.small_icon = small if File.file?(small)
          command.large_icon = large if File.file?(large)
          toolbar.add_item(command)
        end
        toolbar.show
        @hot_commands_registered = true
      end
    end
  end
end

ORAMBO::FaceTools::Diagnostics.register_hot_commands if defined?(Sketchup) && defined?(ORAMBO::FaceTools::Toolbar)
