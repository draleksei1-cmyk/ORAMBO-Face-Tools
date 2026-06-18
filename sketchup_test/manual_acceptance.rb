# frozen_string_literal: true

# Load this file from Window -> Ruby Console:
# load 'C:/path/to/sketchup_test/manual_acceptance.rb'
# Then create a scenario, select the generated group, and run a toolbar command.

module ORAMBO
  module FaceTools
    module ManualAcceptance
      PREFIX = 'ORAMBO_TEST_'
      module_function

      def clear
        model = Sketchup.active_model
        model.start_operation('Clear ORAMBO test geometry', true)
        model.active_entities.grep(Sketchup::Group).select { |group| group.name.start_with?(PREFIX) }.each(&:erase!)
        model.commit_operation
      end

      def square
        build('SQUARE') do |entities|
          loop_edges(entities, [[0, 0, 0], [1000.mm, 0, 0], [1000.mm, 1000.mm, 0], [0, 1000.mm, 0]])
        end
      end

      def small_gap
        build('SMALL_GAP') do |entities|
          points = [[0.5.mm, 0, 0], [1000.mm, 0, 0], [1000.mm, 1000.mm, 0], [0, 1000.mm, 0], [0, 0, 0]]
          points.each_cons(2) { |left, right| entities.add_line(left, right) }
        end
      end

      def large_gap
        build('LARGE_GAP') do |entities|
          points = [[5.mm, 0, 0], [1000.mm, 0, 0], [1000.mm, 1000.mm, 0], [0, 1000.mm, 0], [0, 0, 0]]
          points.each_cons(2) { |left, right| entities.add_line(left, right) }
        end
      end

      def noncoplanar
        build('NONCOPLANAR') do |entities|
          loop_edges(entities, [[0, 0, 0], [1000.mm, 0, 5.mm], [1000.mm, 1000.mm, -3.mm], [0, 1000.mm, 2.mm]])
        end
      end

      def nested_rotated
        outer = build('NESTED_ROTATED') do |entities|
          inner = entities.add_group
          loop_edges(inner.entities, [[0, 0, 10.mm], [1000.mm, 0, 20.mm], [1000.mm, 1000.mm, -5.mm], [0, 1000.mm, 4.mm]])
          inner.transform!(Geom::Transformation.rotation(ORIGIN, X_AXIS, 12.degrees))
          inner.transform!(Geom::Transformation.translation([500.mm, 200.mm, 300.mm]))
        end
        select(outer)
      end

      def component_instances
        model = Sketchup.active_model
        definition = model.definitions.add("#{PREFIX}DEFINITION")
        loop_edges(definition.entities, [[0, 0, 0], [1000.mm, 0, 5.mm], [1000.mm, 1000.mm, 0], [0, 1000.mm, 0]])
        first = model.active_entities.add_instance(definition, Geom::Transformation.new)
        second = model.active_entities.add_instance(definition, Geom::Transformation.translation([1500.mm, 0, 0]))
        first.name = "#{PREFIX}COMPONENT_SELECTED"
        second.name = "#{PREFIX}COMPONENT_CONTROL"
        select(first)
        first
      end

      def curve
        build('CURVE') do |entities|
          entities.add_arc(ORIGIN, X_AXIS, Y_AXIS, 500.mm, 0, Math::PI, 12)
        end
      end

      def locked_and_hidden
        group = build('LOCKED_HIDDEN') do |entities|
          hidden = entities.add_group
          hidden.entities.add_line([0, 0, 0], [1000.mm, 0, 0])
          hidden.hidden = true
          locked = entities.add_group
          locked.entities.add_line([0, 100.mm, 0], [1000.mm, 100.mm, 0])
          locked.locked = true
        end
        select(group)
      end

      def mirrored_component
        instance = component_instances
        instance.name = "#{PREFIX}MIRRORED"
        instance.transform!(Geom::Transformation.scaling(ORIGIN, -1, 1, 1))
        select(instance)
      end

      def create_all
        clear
        [square, small_gap, large_gap, noncoplanar, nested_rotated, curve, locked_and_hidden]
      end

      def build(name)
        model = Sketchup.active_model
        model.start_operation("Create #{name}", true)
        group = model.active_entities.add_group
        group.name = "#{PREFIX}#{name}"
        yield group.entities
        model.commit_operation
        select(group)
        puts "Created #{group.name}. Expected behavior is documented in README.md."
        group
      rescue StandardError
        model.abort_operation
        raise
      end

      def loop_edges(entities, points)
        points.each_with_index { |point, index| entities.add_line(point, points[(index + 1) % points.length]) }
      end

      def select(entity)
        selection = Sketchup.active_model.selection
        selection.clear
        selection.add(entity)
      end
    end
  end
end

puts 'ORAMBO manual scenarios loaded. Example: ORAMBO::FaceTools::ManualAcceptance.square'
