require "./base/model"

module PlaceOS::Model
  class Edge < ModelBase
    include RethinkORM::Timestamps

    table :edge

    attribute name : String, es_subfield: "keyword"

    attribute description : String = ""

    attribute api_key_id : String, presence: true, mass_assignment: false

    @[JSON::Field(ignore: true)]
    getter x_api_key : String do
      self.api_key.as(ApiKey).x_api_key.as(String)
    end

    # Creation
    ###############################################################################################

    record(
      CreateBody,
      name : String,
      description : String = "",
    ) { include JSON::Serializable }

    def self.create(request_body : Edge::CreateBody, user : User)
      Edge.new(
        name: request_body.name,
        description: request_body.description,
      ).tap do |edge|
        edge.set_id
        key = ApiKey.new(name: "Edge X-API-KEY for #{name}")
        key.user = user
        key.scopes = [self.edge_scope(edge.id.as(String))]
        key.save!
        edge.api_key_id = key.id.as(String)

        begin
          edge.save!
        rescue error : RethinkORM::Error
          # Ensure api_key is cleaned up
          key.destroy
          raise error
        end
      end
    end

    # Serialization
    ###############################################################################################

    define_to_json :public, only: [
      :name, :description, :api_key_id, :created_at, :updated_at,
    ], methods: [:x_api_key, :id]

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
      create_index: true,
      association_name: "api_key",
      presence: true,
    )

    # Callbacks
    ###############################################################################################

    before_create :set_id
    before_create :set_api_key

    # Generate ID before document is created
    protected def set_id
      if @id.nil?
        self._new_flag = true
        @id = RethinkORM::IdGenerator.next(self)
      end
    end

    # Create an ApiKey with the Edge id as a scope
    protected def set_api_key
      if key = api_key
        self.api_key_id = key.id.as(String)
      end
    end

    # Api Key methods
    ###############################################################################################

    EDGE_SCOPE_PREFIX = "ei|"

    def self.edge_scope(id : String) : UserJWT::Scope
      UserJWT::Scope.new(EDGE_SCOPE_PREFIX + id)
    end

    def self.scope_edge_id?(jwt : UserJWT) : String?
      jwt
        .scopes
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
