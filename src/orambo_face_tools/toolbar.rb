# frozen_string_literal: true

module ORAMBO
  module FaceTools
    module Toolbar
      module_function

      COMMANDS = [
        ['Break To Segments', 'break_segments', 'Разбить и подготовить сложную DWG-геометрию', -> { BreakToSegments.run }],
        ['Flatten Edges To Z', 'flatten_edges', 'Положить вершины рёбер в мировую Z-плоскость', -> { FlattenEdgesToZ.run }],
        ['Make Faces', 'make_faces', 'Создать грани по замкнутым контурам', -> { MakeFaces.run }]
      ].freeze

      def register
        return @toolbar if @registered
        @registered = true
        menu = UI.menu('Extensions').add_submenu(FaceTools::EXTENSION_NAME)
        @toolbar = UI::Toolbar.new(FaceTools::EXTENSION_NAME)
        COMMANDS.each do |label, icon_name, help, action|
          command = UI::Command.new(label, &action)
          command.tooltip = label
          command.status_bar_text = help
          set_icons(command, icon_name)
          menu.add_item(command)
          @toolbar.add_item(command)
        end
        @toolbar.show
        @toolbar
      end

      def set_icons(command, name)
        icon_dir = File.join(__dir__, 'icons')
        small = File.join(icon_dir, "#{name}_16.png")
        large = File.join(icon_dir, "#{name}_24.png")
        command.small_icon = small if File.file?(small)
        command.large_icon = large if File.file?(large)
      end
    end
  end
end
