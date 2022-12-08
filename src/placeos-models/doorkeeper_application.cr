require "json"
require "time"

require "random/secure"
require "./base/model"
require "digest/md5"

module PlaceOS::Model
  class DoorkeeperApplication < ModelBase
    include PlaceOS::Model::Timestamps

    table :doorkeeper_app

    attribute name : String, es_subfield: "keyword"
    attribute secret : String
    attribute scopes : String = "public"
    attribute owner_id : String, es_type: "keyword"
    attribute redirect_uri : String
    attribute skip_authorization : Bool = true
    attribute confidential : Bool = false
    attribute revoked_at : Time?, converter: Time::EpochConverter

    attribute uid : String, mass_assignment: false

    # Validation
    ###############################################################################################

    ensure_unique :uid

    ensure_unique :redirect_uri do |redirect_uri|
      redirect_uri.strip
    end

    ensure_unique :name do |name|
      name.strip
    end

    validates :name, presence: true
    validates :secret, presence: true
    validates :redirect_uri, presence: true

    # Callbacks
    ###############################################################################################

    before_save :generate_uid

    before_create :generate_secret

    protected def generate_uid
      check_uid = @uid
      if check_uid.nil? || check_uid.blank?
        redirect = self.redirect_uri.downcase
        if redirect.starts_with?("http")
          self.uid = Digest::MD5.hexdigest(redirect)
        else
          self.uid = Random::Secure.urlsafe_base64(25)
        end

        current_id = @id
        if current_id.nil?
          # Ensure document is treated as unpersisted
          self.new_record = true
          @id = self.uid
        end
      end
    end

    protected def generate_secret
      self.secret = Random::Secure.urlsafe_base64(40)
    end
  end
end
