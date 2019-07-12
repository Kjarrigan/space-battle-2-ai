# frozen_string_literals:true

require_relative 'unit'

module Game
  class Map
    VECTOR_TO_DIRECTION = {
      Vector[ 1,  0] => 'E',
      Vector[ 1,  1] => 'S', # SE
      Vector[ 0,  1] => 'S',
      Vector[-1,  1] => 'S', # SW
      Vector[-1,  0] => 'W',
      Vector[-1, -1] => 'N', # NW
      Vector[ 0, -1] => 'N',
      Vector[ 1, -1] => 'N' # NE
    }.freeze

    # Your position is always relative to your base at (0, 0)
    # TODO, check for blocked tiles
    def guide_me_home(vec)
      VECTOR_TO_DIRECTION[(Vector[0, 0] - vec).orientation]
    end

    # TODO, cache if there are no known ressources nearby
    def direction_of_nearest(_type, vec)
      ress = {}
      @tiles.each do |pos, tile|
        ress[(pos - vec).magnitude] = tile if tile['resources']
      end

      if ress.empty?
        # If there is no known field with the searched type
        # than randomly go somewhere
        # TODO, random -> toward unknown terrain
        [VECTOR_TO_DIRECTION.values.sample, false]
      else
        distance, tile = ress.min
        [
          VECTOR_TO_DIRECTION[(tile.position - vec).orientation],
          distance == 1
        ]
      end
    end

    attr_reader :tiles
    def initialize
      @tiles = {}
    end

    class Tile < Hash; end
    def update_tiles(tile_updates)
      tile_updates.each do |tile|
        pos = Vector[tile['x'], tile['y']]
        @tiles[pos] ||= Tile.new
        @tiles[pos].update(tile)
      end
    end
  end
end

Game.start(ARGV[0] || 9090) if $PROGRAM_NAME == __FILE__
