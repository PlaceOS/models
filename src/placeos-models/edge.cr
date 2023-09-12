require "./base/model"
require "./user"
require "./api_key"

module PlaceOS::Model
  class Edge < ModelBase
    include PlaceOS::Model::Timestamps

    table :edge

    attribute name : String, es_subfield: "keyword"

    attribute description : String = ""

    attribute api_key_id : String, mass_assignment: false

    attribute user_id : String, mass_assignment: false
    attribute last_seen : Time?, mass_assignment: false
    attribute online : Bool = false, mass_assignment: false

    @[JSON::Field(ignore: true)]
    getter x_api_key : String do
      self.api_key.as(ApiKey).x_api_key.as(String)
    end

    CONTROL_SCOPE = "edge-control"

    define_to_json :key, methods: :x_api_key

    # Creation
    ###############################################################################################

    macro finished
      def api_key=(key)
        self.user_id = key.user_id.as(String)
        previous_def(key)
      end
    end

    def self.for_user(user : Model::User, **attributes)
      Model::Edge.new(**attributes).tap do |edge|
        edge.set_id
        key = ApiKey.new(name: "Edge X-API-KEY for #{edge.name}")
        key.safe_id
        key.user = user
        key.scopes = [
          Model::Edge.edge_scope(edge.id.as(String)),
          UserJWT::Scope.new(CONTROL_SCOPE),
        ]
        edge.api_key = key
      end
    end

    def save!(**options)
      super(**options)
    rescue error : PgORM::Error
      # Ensure api_key is cleaned up
      self.api_key.try(&.destroy)
      raise error
    end

    record(
      CreateBody,
      name : String,
      user_id : String?,
      description : String = "",
    ) do
      include JSON::Serializable
      extend OpenAPI::Generator::Serializable
    end

    # Association
    ###############################################################################################

    # Modules allocated to this Edge
    has_many(
      child_class: Module,
      collection_name: "modules",
      foreign_key: "edge_id",
    )

    # Edges authenticate with an X-API-KEY
    has_one(
      child_class: ApiKey,
      dependent: :destroy,
      association_name: "api_key",
      presence: false,
    )

    # Callbacks
    ###############################################################################################

    before_create :set_id
    before_create :save_api_key

    # Generate ID before document is created
    protected def set_id
      if @id.nil?
        self.new_record = true
        @id = Utilities::IdGenerator.next(self)
      end
    end

    protected def save_api_key
      raise Model::Error.new("No ApiKey associated with Edge") if (key = self.api_key).nil?

      # Ensure `user_id` is set
      self.user_id = key.user_id.as(String)

      key.save!
    end

    # Api Key methods
    ###############################################################################################

    EDGE_SCOPE_PREFIX = "ei|"

    def self.edge_scope(id : String) : UserJWT::Scope
      UserJWT::Scope.new(EDGE_SCOPE_PREFIX + id)
    end

    def self.jwt_edge_id?(jwt : UserJWT) : String?
      jwt
        .scope
        .find(&.resource.starts_with?(EDGE_SCOPE_PREFIX))
        .try(&.resource.lchop(EDGE_SCOPE_PREFIX))
    end

    # Validation
    ###############################################################################################

    ensure_unique :name do |name|
      name.strip
    end
  end
end
