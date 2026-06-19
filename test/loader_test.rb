# frozen_string_literal: true

require_relative 'test_helper'

module Sketchup
  class << self
    attr_accessor :registered_extension
  end

  def self.register_extension(extension, enabled)
    self.registered_extension = [extension, enabled]
  end
end

class SketchupExtension
  attr_accessor :description, :version, :creator
  attr_reader :name, :loader

  def initialize(name, loader)
    @name, @loader = name, loader
  end
end

module UI
  class Command
    attr_accessor :small_icon, :large_icon, :tooltip, :status_bar_text
    attr_reader :name

    def initialize(name, &block)
      @name, @block = name, block
    end
  end

  class Menu
    attr_reader :items
    def initialize
      @items = []
    end
    def add_submenu(_name)
      self
    end
    def add_item(command)
      @items << command
    end
  end

  class Toolbar
    attr_reader :items
    def initialize(_name)
      @items = []
    end
    def add_item(command)
      @items << command
    end
    def show; end
  end

  class << self
    attr_accessor :extensions_menu, :timers
  end

  def self.menu(_name)
    self.extensions_menu ||= Menu.new
  end

  def self.start_timer(interval, repeat, &block)
    self.timers ||= []
    self.timers << [interval, repeat, block]
  end
end

class LoaderTest < Minitest::Test
  ROOT = File.expand_path('../src', __dir__)

  def test_extension_metadata
    $LOAD_PATH.unshift(File.expand_path('support', __dir__))
    load File.join(ROOT, 'orambo_face_tools.rb')
    extension, enabled = Sketchup.registered_extension
    assert enabled
    assert_equal 'ORAMBO Face Tools', extension.name
    assert_equal '0.1.1', extension.version
    assert_equal 'ORAMBO', extension.creator
  ensure
    $LOAD_PATH.shift
  end

  def test_toolbar_has_five_commands_without_icons
    ORAMBO::FaceTools.const_set(:EXTENSION_NAME, 'ORAMBO Face Tools') unless ORAMBO::FaceTools.const_defined?(:EXTENSION_NAME)
    require_relative '../src/orambo_face_tools/diagnostics'
    load File.join(ROOT, 'orambo_face_tools', 'toolbar.rb')
    UI.extensions_menu = UI::Menu.new
    ORAMBO::FaceTools::Toolbar.instance_variable_set(:@registered, false)
    toolbar = ORAMBO::FaceTools::Toolbar.register
    expected = ['Break To Segments', 'Flatten Edges To Z', 'Make Faces', 'Select Open Ends', 'Highlight Gaps']
    assert_equal expected, toolbar.items.map(&:name)
    assert_equal expected + ['Check for Updates'],
                 UI.extensions_menu.items.map(&:name)
  end

  def test_hot_registration_adds_diagnostics_once
    require_relative '../src/orambo_face_tools/diagnostics'
    load File.join(ROOT, 'orambo_face_tools', 'toolbar.rb')
    toolbar = UI::Toolbar.new('ORAMBO Face Tools')
    ['Break To Segments', 'Flatten Edges To Z', 'Make Faces'].each do |name|
      toolbar.add_item(UI::Command.new(name))
    end
    ORAMBO::FaceTools::Toolbar.instance_variable_set(:@toolbar, toolbar)
    ORAMBO::FaceTools::Diagnostics.instance_variable_set(:@hot_commands_registered, false)

    ORAMBO::FaceTools::Diagnostics.register_hot_commands
    ORAMBO::FaceTools::Diagnostics.register_hot_commands

    assert_equal ['Break To Segments', 'Flatten Edges To Z', 'Make Faces', 'Select Open Ends', 'Highlight Gaps'],
                 toolbar.items.map(&:name)
  end

  def test_updater_schedules_one_delayed_non_repeating_check
    require_relative '../src/orambo_face_tools/updater'
    UI.timers = []
    ORAMBO::FaceTools::Updater.instance_variable_set(:@auto_check_scheduled, false)
    ORAMBO::FaceTools::Updater.schedule_auto_check
    ORAMBO::FaceTools::Updater.schedule_auto_check
    assert_equal 1, UI.timers.length
    assert_equal [5.0, false], UI.timers.first.first(2)
  end
end
