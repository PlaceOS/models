# Adds version history to a `PlaceOS::Model`
module PlaceOS::Model::Utilities::Versions
  # Number of version models to retain
  MAX_VERSIONS = (ENV["PLACE_MAX_VERSIONS"]?.try(&.to_i?) || 20)

  # Make relevant updates to version before it is saved
  abstract def create_version(version : self) : self

  macro included
    {% klass_name = @type.id.split("::").last.underscore.id %}
    {% parent_id = "#{klass_name}_id".id %}

    # Associate with main version
    attribute {{ parent_id }} : String?
    #secondary_index {{ parent_id.symbolize }}

    has_many(
      child_class: {{ @type }},
      collection_name: {{ klass_name.stringify }},
      foreign_key: {{ parent_id.stringify }},
      dependent: :destroy
    )

    # If a {{ @type }} has a parent, it's a version
    def is_version? : Bool
      !{{ parent_id }}.nil?
    end

    # Callbacks
    ###########################################################################

    after_save :__create_version__
    after_save :cleanup_history

    protected def __create_version__
      return if is_version?

      saved_created = created_at
      saved_updated = updated_at

      @created_at = nil
      @updated_at = nil

      version = self.dup
      version.id = nil
      version.new_record = true
      version.{{ parent_id }} = self.id
      create_version(version).save!

      self.created_at = saved_created
      self.updated_at = saved_updated
    end

    private def cleanup_history
      return if is_version?
      query = {{@type}}.all
      ids = associated_version_query(query, &.itself)
        .offset(MAX_VERSIONS)
        .pluck(:id)
      {{@type}}.where(id: ids).delete_all unless ids.empty?
    end

    # Queries
    ###########################################################################

    # Get version history
    #
    # Versions are in descending order of creation
    def history(offset : Int32 = 0, limit : Int32 = 10, &)
      query = {{@type}}.all
      associated_version_query(query) do |query_builder|
        (yield query_builder).offset(offset).limit(limit)
      end.to_a
    end

    # :ditto:
    def history(offset : Int32 = 0, limit : Int32 = 10)
      history(offset, limit, &.itself)
    end

    # Return the number of versions for the main record.
    #
    # If the record is a version, this is always 0.
    def history_count
      return 0 if is_version?
      query = {{@type}}.all
      associated_version_query(query, &.itself).unscope(:order).count
    end

    private def associated_version_query(query_builder)
      query_builder = query_builder
        .where({{parent_id}}: id)
      query_builder = yield query_builder
      query_builder.order(created_at: :desc)
    end

    # Query on main {{ klass_name }} records
    #
    # Gets records where the {{ parent_id }} does not exist, i.e. is the main
    def self.master_{{ klass_name }}_query(offset : Int32 = 0, limit : Int32 = 100)
      query = {{@type}}.all
      query = yield query
      query = query.where({{parent_id}}: nil)
        .limit(limit)
        .offset(offset)
        .to_a
    end

    # Query on main {{ klass_name }} records
    #
    # Gets records where the {{ parent_id }} does not exist, i.e. is the main
    def self.master_{{ klass_name }}_raw_query(count : Bool = false)
      query = {{@type}}.all
      query = yield query
      query = query.where({{parent_id}}: nil)
    end

    # Count of records returned by query on main {{ klass_name }} records
    #
    # Gets records where the {{ parent_id }} does not exist, i.e. is the main
    def self.master_{{ klass_name }}_query_count
      query = {{@type}}.all
      query = yield query
      query = query.where({{parent_id}}: nil)
        .count
    end
  end
end
