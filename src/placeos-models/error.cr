module PlaceOS::Model
  class Error < Exception
    getter message

    def initialize(@message = "", @cause = nil)
    end
  end

  class NoParentError < Error
  end

  class NoScope < Error
  end

  class InvalidEmail < Error
  end

  class MalformedFilter < Error
    def initialize(filters : Array(String)?)
      super("One or more invalid regexes: #{filters}")
    end
  end
end
