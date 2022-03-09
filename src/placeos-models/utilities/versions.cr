require "rethinkdb-orm"

# Adds version history to a `PlaceOS::Model`
module PlaceOS::Model::Utilities::Versions
  macro included
    {% klass_name = @type.id.split("::").last.underscore.id %}
    {% parent_id = "#{klass_name}_id".id %}

    attribute {{ parent_id }} : String?
    secondary_index {{ parent_id.symbolize }}

    # {{ @type }} self-referential entity relationship acts as a 2-level tree
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

    protected def __create_version__
      return if is_version?

      saved_created = created_at
      saved_updated = updated_at

      @created_at = nil
      @updated_at = nil

      version = self.dup
      version.id = nil
      version.{{ parent_id }} = self.id
      if version.responds_to? :modified_by && self.responds_to? :modified_by
        version.modified_by = self.modified_by.as(User)
      end
      create_version(version).save!

      self.created_at = saved_created
      self.updated_at = saved_updated
    end

    # Queries
    ###########################################################################

    # Get version history
    #
    # Versions are in descending order of creation
    def history(offset : Int32 = 0, limit : Int32 = 10)
      {{ @type }}.raw_query do |r|
        r
          .table({{ @type }}.table_name)
          .get_all([parent_id.as(String)], index: :parent_id)
          .filter({
            {{ parent_id }}: id.as(String)
          })
          .order_by(r.desc(:created_at)).slice(offset, offset + limit)
      end.to_a
    end

    # Get {{ @type }} for given parent id/s
    #
    def self.for_parent(parent_ids : String | Array(String)) : Array(self)
      master_{{ klass_name }}_query(parent_ids, &.itself)
    end

    # Query on master {{ klass_name }} associated with ids
    #
    # Gets documents where the {{ parent_id }} does not exist, i.e. is the master
    def self.master_{{ klass_name }}_query(ids : String | Array(String))
      cursor = query(ids) do |q|
        yield q.filter(&.has_fields({{ parent_id.symbolize }}).not)
      end

      cursor.to_a
    end
  end

  # Make relevant updates to version before it is saved
  abstract def create_version(version : self) : self
end
