# frozen_string_literal: true

module ORAMBO
  module FaceTools
    module Utils
      module_function

      def coordinates(point)
        [point.x.to_f, point.y.to_f, point.z.to_f]
      end

      def grid_key(point, cell_size)
        raise ArgumentError, 'cell_size must be positive' unless cell_size.to_f.positive?
        coordinates(point).map { |value| (value / cell_size.to_f).floor }
      end

      def canonical_edge_key(point_a, point_b, tolerance)
        raise ArgumentError, 'tolerance must be positive' unless tolerance.to_f.positive?
        quantize = lambda { |point| coordinates(point).map { |value| (value / tolerance.to_f).round } }
        [quantize.call(point_a), quantize.call(point_b)].sort
      end

      def z_spread_values(values)
        numbers = values.map(&:to_f)
        return { min_z: nil, max_z: nil, spread: 0.0 } if numbers.empty?
        minimum, maximum = numbers.minmax
        { min_z: minimum, max_z: maximum, spread: maximum - minimum }
      end

      def mirrored_axes?(xaxis, yaxis, zaxis)
        x = vector_values(xaxis)
        y = vector_values(yaxis)
        z = vector_values(zaxis)
        cross = [x[1] * y[2] - x[2] * y[1], x[2] * y[0] - x[0] * y[2], x[0] * y[1] - x[1] * y[0]]
        (cross[0] * z[0] + cross[1] * z[1] + cross[2] * z[2]).negative?
      rescue StandardError
        false
      end

      def mirrored_transform?(transform)
        mirrored_axes?(transform.xaxis, transform.yaxis, transform.zaxis)
      end

      def contains_hidden_geometry?(container)
        return false unless container.respond_to?(:definition) && container.definition.respond_to?(:entities)
        container.definition.entities.any? do |entity|
          (entity.respond_to?(:hidden?) && entity.hidden?) || contains_hidden_geometry?(entity)
        end
      rescue StandardError
        false
      end

      def vector_values(vector)
        vector.respond_to?(:to_a) ? vector.to_a.first(3).map(&:to_f) : vector.first(3).map(&:to_f)
      end

      def active_context_transform(model)
        transform = Geom::Transformation.new
        Array(model.active_path).each { |instance| transform *= instance.transformation }
        transform
      end

      def count_edges_in_selection(selection, deep: true)
        count = 0
        walk = lambda do |entity|
          if entity.is_a?(Sketchup::Edge)
            count += 1
          elsif deep && container?(entity) && !entity.locked?
            entity.definition.entities.each { |child| walk.call(child) }
          end
        end
        selection.each { |entity| walk.call(entity) }
        count
      end

      def collect_edge_contexts(model, selection, include_hidden: false, make_unique: false, deep: true, warnings: [])
        contexts = {}
        base = active_context_transform(model)
        visit = lambda do |entity, transform, container|
          if entity.is_a?(Sketchup::Edge)
            if entity.hidden? && !include_hidden
              warnings << 'Скрытое ребро пропущено.'
            else
              key = entity.parent.object_id
              record = (contexts[key] ||= { entities: entity.parent, edges: [], transform: transform, container: container })
              record[:edges] << entity
            end
          elsif container?(entity) && deep
            if entity.locked?
              warnings << 'Заблокированный объект пропущен.'
              next
            end
            if entity.hidden? && !include_hidden
              warnings << 'Скрытый объект пропущен.'
              next
            end
            entity.make_unique if make_unique && entity.is_a?(Sketchup::ComponentInstance)
            child_transform = transform * entity.transformation
            entity.definition.entities.each { |child| visit.call(child, child_transform, entity) }
          end
        rescue StandardError => error
          warnings << "Объект пропущен: #{error.message}"
        end
        selection.each { |entity| visit.call(entity, base, nil) }
        contexts.values
      end

      def container?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end

      def select_result(model, container)
        return unless container
        model.selection.clear
        model.selection.add(container) if container && container.valid?
      rescue StandardError
        nil
      end
    end
  end
end
