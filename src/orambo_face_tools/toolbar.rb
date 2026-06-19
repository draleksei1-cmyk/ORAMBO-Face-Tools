# frozen_string_literal: true

module ORAMBO
  module FaceTools
    module Toolbar
      module_function

      remove_const(:COMMANDS) if const_defined?(:COMMANDS, false)
      COMMANDS = [
        ['Break To Segments', 'break_segments', 'Разбить и подготовить сложную DWG-геометрию', -> { BreakToSegments.run }],
        ['Flatten Edges To Z', 'flatten_edges', 'Положить вершины рёбер в мировую Z-плоскость', -> { FlattenEdgesToZ.run }],
        ['Make Faces', 'make_faces', 'Создать грани по замкнутым контурам', -> { MakeFaces.run }],
        ['Select Open Ends', 'open_ends', 'Показать свободные концы красными крестиками', -> { Diagnostics.run_open_ends }],
        ['Highlight Gaps', 'highlight_gaps', 'Показать ближайшие разрывы между контурами', -> { Diagnostics.run_highlight_gaps }]
      ].freeze

      def register
        return @toolbar if @registered
        @registered = true
        menu = UI.menu('Extensions').add_submenu(FaceTools::EXTENSION_NAME)
        @toolbar = UI::Toolbar.new(FaceTools::EXTENSION_NAME)
        COMMANDS.each do |label, icon_name, help, action|
          command = build_command(label, icon_name, help, action)
          menu.add_item(command)
          @toolbar.add_item(command)
        end
        update_command = UI::Command.new('Check for Updates') { Updater.check_for_updates(manual: true) }
        update_command.tooltip = 'Check for Updates'
        update_command.status_bar_text = 'Проверить обновления ORAMBO Face Tools на GitHub'
        menu.add_item(update_command)
        @toolbar.show
        @toolbar
      end

      def build_command(label, icon_name, help, action)
        command = UI::Command.new(label, &action)
        command.tooltip = label
        command.status_bar_text = help
        set_icons(command, icon_name)
        command
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
