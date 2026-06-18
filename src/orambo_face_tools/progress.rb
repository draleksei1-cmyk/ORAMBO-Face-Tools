# frozen_string_literal: true

module ORAMBO
  module FaceTools
    class Progress
      class << self
        def start(label, total = nil)
          @label, @total, @current = label, total, 0
          message(total ? "#{label}: 0 из #{total}" : label)
        end

        def tick(current = nil)
          @current = current || @current.to_i + 1
          return unless (@current % 500).zero? || @current == @total
          message(@total ? "#{@label}: обработано #{@current} из #{@total}" : "#{@label}: #{@current}")
        end

        def message(text)
          Sketchup.status_text = "ORAMBO Face Tools: #{text}" if defined?(Sketchup)
        end

        def finish
          Sketchup.status_text = '' if defined?(Sketchup)
          @label = @total = @current = nil
        end
      end

      def initialize(label, total, interval: 250)
        @label, @total, @interval = label, [total.to_i, 1].max, [interval.to_i, 1].max
      end

      def update(index)
        return unless defined?(Sketchup) && (index % @interval).zero?
        Sketchup.status_text = "#{@label}: #{index}/#{@total}"
      end

      def finish
        Sketchup.status_text = '' if defined?(Sketchup)
      end
    end
  end
end
