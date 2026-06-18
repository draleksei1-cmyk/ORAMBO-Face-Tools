# frozen_string_literal: true

require 'sketchup.rb'
require 'extensions.rb'

module ORAMBO
  module FaceTools
    EXTENSION_NAME = 'ORAMBO Face Tools' unless const_defined?(:EXTENSION_NAME)
    EXTENSION_VERSION = '0.1.0' unless const_defined?(:EXTENSION_VERSION)
  end
end

loader = File.join(__dir__, 'orambo_face_tools', 'main.rb')
extension = SketchupExtension.new(ORAMBO::FaceTools::EXTENSION_NAME, loader)
extension.description = 'DWG cleanup tools: Break To Segments, Flatten Edges To Z, Make Faces.'
extension.version = ORAMBO::FaceTools::EXTENSION_VERSION
extension.creator = 'ORAMBO'
Sketchup.register_extension(extension, true)
