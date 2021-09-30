require "./base/model"

module PlaceOS::Model
  struct Email
    getter address : String
    forward_missing_to address

    def initialize(address : String)
      @address = address.strip
    end

    def initialize(json : JSON::PullParser)
      @address = json.read_string.strip
    end

    def self.from_json(pull)
      new pull
    end

    def to_s(io)
      io << @address
    end

    def valid?
      address.is_email?
    end

    def digest
      Digest::MD5.hexdigest(@address.strip.downcase)
    end
  end
end
