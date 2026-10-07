module PlaceOS
  module Model
    class Error < Exception
      getter message

      def initialize(io : IO, **args)
        super(io.to_s, **args)
      end

      def initialize(@message = "", **args)
        super
      end

      class NoParent < Error
      end

      class InvalidSaasKey < Error
      end

      class NoScope < Error
      end

      # The user has no usable SSO resource token (see `User#resource_token`)
      class NoResourceToken < Error
      end

      class MalformedFilter < Error
        def initialize(filters : Array(String)?)
          super("One or more invalid regexes: #{filters}")
        end
      end
    end
  end
end
