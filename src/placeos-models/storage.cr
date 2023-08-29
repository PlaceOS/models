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

    attribute ext_filter : Array(String) = [] of String
    attribute mime_filter : Array(String) = [] of String

    validates :bucket_name, presence: true
    validates :access_key, presence: true
    validates :access_secret, presence: true

    before_create {
      rec = Model::Storage.find_by?(authority_id: authority_id, storage_type: storage_type.to_s.upcase, bucket_name: bucket_name)
      raise Model::Error.new("authority_id need to be unique") unless rec.nil?
    }

    before_save {
      @ext_filter = ext_filter.map do |ext|
        ext = ext[1..] if ext.starts_with?('.')
        ext.downcase
      end
      @mime_filter = ext_filter.map(&.downcase)
      self.access_secret = PlaceOS::Encryption.encrypt(access_secret, level: level, id: encryption_id)
    }

    def decrypt_secret
      PlaceOS::Encryption.decrypt(access_secret, level: level, id: encryption_id)
    end

    def self.storage_or_default(authority_id : String?) : Storage
      model = Storage.find_by?(authority_id: authority_id) || Storage.find_by?(authority_id: nil)
      raise Model::Error.new("Could not find Default or authority '#{authority_id}' Storage") if model.nil?
      model
    end

    def check_file_ext(ext : String)
      raise Model::Error.new("File extension not allowed") unless file_ext_allowed(ext)
    end

    def check_file_mime(mime : String)
      raise Model::Error.new("File mimetype not allowed") unless file_mime_allowed(mime)
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

    private def file_ext_allowed(ext : String)
      return true if ext_filter.empty?
      ext_filter.includes?(ext.lstrip('.').downcase)
    end

    private def file_mime_allowed(mime : String)
      return true if mime_filter.empty?
      mime_filter.includes?(mime.downcase)
    end
  end
end
