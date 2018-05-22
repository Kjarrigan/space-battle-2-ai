# frozen_string_literals:true

require 'pp'
require 'socket'
require 'thread'
require 'json'
require 'matrix'

class Hash
  alias update merge!

  def position
    Vector[self['x'], self['y']]
  end
end

class Vector
  def orientation
    map do |val|
      val / val.abs rescue 0
    end
  end
end

class Game
  class Unit < Hash
    def initialize(params = {})
      update(params)
    end

    def self.from_type(params = {})
      const_get(params.delete('type').capitalize).new(params)
    end

    def act!; end

    def log(msg)
      puts "#{self.class}##{self['id']}: #{msg}"
    end

    class Base < Unit; end

    class Worker < Unit
      def act!
        log "I'm #{self['status']}"
        return unless self['status'] == 'idle'

        if self['resource'].zero?
          dir, adjacent = Map.direction_of_nearest(:resource, position)
          if adjacent
            gather(dir)
          else
            move(dir)
          end
        else
          dir = Map.guide_me_home(position)
          move(dir)
        end
      end

      def move(direction)
        log "I'll fly #{direction}!"
        { command: 'MOVE', unit: self['id'], dir: direction }
      end

      def gather(direction)
        log "I'll gather resources #{direction}!"
        { command: 'GATHER', unit: self['id'], dir: direction }
      end
    end
  end

  # rubocop:disable Metrics/BlockLength
  Map ||= Class.new do
    # rubocop:disable Layout/SpaceInsideReferenceBrackets
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
    # rubocop:enable Layout/SpaceInsideReferenceBrackets

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
  end.new
  # rubocop:enable Metrics/BlockLength

  def initialize
    @my_units = {}
  end

  def process_updates_from_server(msgs)
    msgs.each do |msg|
      Map.update_tiles(msg['tile_updates'])

      # TODO, parse Turn 0 Infos (like Gametime, UnitStats, etc)
      msg['unit_updates'].each do |uu|
        @my_units[uu['id']] ||= Unit.from_type(uu)
        @my_units[uu['id']].update(uu)
      end
    end

    { commands: @my_units.values.map(&:act!).compact }
  end

  def self.start(port)
    server = TCPServer.new port
    Thread.abort_on_exception = true
    loop do
      puts "waiting for connection on #{port}"
      Thread.new(server.accept) do |server_connection|
        msg_queue = Queue.new

        start_listener(server_connection, msg_queue)
        run!(new, server_connection, msg_queue)

        server_connection.close
      end
    end
  end

  def self.start_listener(server_connection, msg_queue)
    Thread.new do
      begin
        while (msg = server_connection.gets)
          msg_queue.push JSON.parse(msg)
        end
      end
    end
  end

  def self.run!(game, server_connection, msg_queue)
    loop do
      msg = msg_queue.pop
      msgs = [msg]
      until msg_queue.empty?
        puts '!!! missed turn!'
        msgs << msg_queue.pop
      end

      commands = game.process_updates_from_server(msgs)
      server_connection.puts(commands.to_json)
    end
  end
end

Game.start(ARGV[0] || 9090) if $PROGRAM_NAME == __FILE__
