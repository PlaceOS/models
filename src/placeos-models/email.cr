require "./base/model"

module PlaceOS::Model
  struct Email
    getter address : String
    forward_missing_to address

    def initialize(@address : String)
    end

    def initialize(json : JSON::PullParser)
      email = self.class.from_json(json)
      @address = email.address
    end

    def self.from_json(pull)
      new pull.read_string
    end

    def to_s
      @address
    end

    def to_s(io)
      io = @address
    end

    def digest
      Digest::MD5.hexdigest(@address.strip.downcase)
    end
  end
end
