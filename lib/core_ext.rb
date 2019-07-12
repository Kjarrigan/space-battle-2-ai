# frozen_string_literals:true

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
