require "rethinkdb-orm"
require "time"

require "./base/model"

module PlaceOS::Model
  # Class that pins engine's drivers to a specifc repository state
  # Allows external driver management from a VCS
  class Repository < ModelBase
    include RethinkORM::Timestamps
    table :repo

    enum Type
      Driver
      Interface
    end

    # Repository metadata
    attribute name : String, es_type: "keyword"
    attribute folder_name : String
    attribute description : String
    attribute uri : String
    attribute commit_hash : String = "head"

    enum_attribute repo_type : Type = Type::Driver, column_type: String, es_type: "text"

    # Validations
    validates :name, presence: true
    validates :folder_name, presence: true
    validates :repo_type, presence: true
    validates :uri, presence: true
    validates :commit_hash, presence: true

    def pull!
      if self.commit_hash == "head"
        self.updated_at = Time.utc
      else
        self.commit_hash = "head"
      end

      self.save!
    end

    # Authentication
    attribute username : String
    attribute password : String
    attribute key : String

    has_many(
      child_class: Driver,
      collection_name: "drivers",
      foreign_key: "repository_id"
    )
  end
end