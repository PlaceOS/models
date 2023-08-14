require "json"

require "./base/model"
require "./utilities/encryption"

module PlaceOS::Model
  class Storage < ModelBase
    include PlaceOS::Model::Timestamps

    enum Type
      S3
      Azure
      Google
    end

    table :storages

    attribute storage_type : Type = Type::S3, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Storage::Type)
    attribute bucket_name : String
    attribute region : String? = "us-east-1"

    attribute access_key : String
    attribute access_secret : String
    attribute authority_id : String?
    attribute endpoint : String?

    validates :bucket_name, presence: true
    validates :access_key, presence: true
    validates :access_secret, presence: true

    validate ->(this : Model::Storage) {
      rec = Model::Storage.find_by?(authority_id: this.authority_id, storage_type: this.storage_type.to_s.upcase, bucket_name: this.bucket_name)
      this.validation_error(:authority_id, "authority_id need to be unique") unless rec.nil?
    }

    before_save {
      self.access_secret = PlaceOS::Encryption.encrypt(access_secret, level: level, id: encryption_id)
    }

    def decrypt_secret
      PlaceOS::Encryption.decrypt(access_secret, level: level, id: encryption_id)
    end

    def self.storage_or_default(authority_id : String?) : Storage
      model = Storage.find_by?(authority_id: authority_id) || Storage.find_by?(authority_id: nil)
      raise Error.new("Could not find Default or authority '#{authority_id}' Storage") if model.nil?
      model
    end

    # Determine if access_secret is encrypted
    #
    def secret_encrypted? : Bool
      PlaceOS::Encryption.is_encrypted?(access_secret)
    end

    private def encryption_id : String
      if (auth = authority_id)
        auth
      else
        access_key
      end
    end

    private def level : PlaceOS::Encryption::Level
      PlaceOS::Encryption::Level::NeverDisplay
    end
  end
end
