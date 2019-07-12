# frozen_string_literals:true

require 'pp'
require 'socket'
require 'thread'
require 'json'

require_relative 'lib/core_ext'
require_relative 'lib/map'
require_relative 'lib/unit'

module Game
  class Match
    attr_reader :map

    def initialize
      @my_units = {}
      @map = Map.new
    end

    def process_updates_from_server(msgs)
      msgs.each do |msg|
        @map.update_tiles(msg['tile_updates'])

        # TODO, parse Turn 0 Infos (like Gametime, UnitStats, etc)
        msg['unit_updates'].each do |uu|
          @my_units[uu['id']] ||= Unit.from_type(@map, uu)
          @my_units[uu['id']].update(uu)
        end
      end

      { commands: @my_units.values.map(&:act!).compact }
    end
  end

  def self.start(port)
    server = TCPServer.new port
    Thread.abort_on_exception = true
    loop do
      puts "waiting for connection on #{port}"
      Thread.new(server.accept) do |server_connection|
        msg_queue = Queue.new

        start_listener(server_connection, msg_queue)
        run!(Match.new, server_connection, msg_queue)

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
