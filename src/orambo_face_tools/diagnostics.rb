# frozen_string_literal: true

require_relative 'utils'

module ORAMBO
  module FaceTools
    module Diagnostics
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
    end
  end
end
