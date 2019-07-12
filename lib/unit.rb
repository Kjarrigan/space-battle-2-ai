module Game
  class Unit < Hash
    attr_reader :map
    def initialize(map, params = {})
      @map = map
      update(params)
    end

    def self.from_type(map, params = {})
      const_get(params.delete('type').capitalize).new(map, params)
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
          dir, adjacent = map.direction_of_nearest(:resource, position)
          if adjacent
            gather(dir)
          else
            move(dir)
          end
        else
          dir = map.guide_me_home(position)
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
end
