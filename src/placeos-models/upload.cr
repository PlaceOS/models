require "json"
require "upload-signer"

require "./base/model"
require "./storage"
require "./email"

module PlaceOS::Model
  class Upload < ModelBase
    include PlaceOS::Model::Timestamps

    enum Permissions
      None
      Admin
      Support
    end

    table :uploads

    attribute uploaded_email : Email = Email.new(""), converter: PlaceOS::Model::EmailConverter

    attribute file_name : String
    attribute file_size : Int64
    attribute file_path : String?
    attribute object_key : String
    attribute file_md5 : String

    attribute public : Bool = false
    attribute permissions : Permissions = Permissions::None, converter: PlaceOS::Model::PGEnumConverter(PlaceOS::Model::Upload::Permissions)
    attribute object_options : Hash(String, JSON::Any) = {} of String => JSON::Any

    attribute resumable_id : String?
    attribute resumable : Bool = false
    attribute part_list : Array(Int32) = -> { [] of Int32 }
    attribute part_data : Hash(String, JSON::Any) = {} of String => JSON::Any
    attribute upload_complete : Bool = false

    # so we can tag which system the upload belongs to
    # allowing us to filter for relevancy
    attribute tags : Array(String) = -> { [] of String }

    belongs_to Storage
    belongs_to User, foreign_key: "uploaded_by", association_name: "user"

    validates :uploaded_by, presence: true
    validates :uploaded_email, presence: true
    validates :file_name, presence: true
    validates :file_size, presence: true
    validates :object_key, presence: true
    validates :file_md5, presence: true

    # Validate no
    validate ->(this : Upload) {
      this.validation_error(:file_name, "contains invalid characters or words") unless Upload.safe_filename?(this.file_name)
    }

    def self.safe_filename?(filename : String) : Bool
      # Regex to detect invalid characters and patterns
      invalid_pattern = /[\x00-\x1F<>:"\/\\|?*#&%=]|\.\.|^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$/i
      filename =~ invalid_pattern ? false : true
    end

    def part_data_changed(flag = true)
      @part_data_changed = flag
    end

    before_destroy :delete_data

    protected def delete_data
      cloud_fs = self.storage rescue nil
      return unless cloud_fs

      signer = UploadSigner.signer(UploadSigner::StorageType.from_value(cloud_fs.storage_type.value), cloud_fs.access_key, cloud_fs.decrypt_secret, cloud_fs.region, endpoint: cloud_fs.endpoint)
      signer.delete_file(cloud_fs.bucket_name, self.object_key, self.resumable_id)
    end
  end
end
