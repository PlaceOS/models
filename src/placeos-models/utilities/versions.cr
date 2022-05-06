require "rethinkdb-orm"

# TODO: Add `RethinkDB::StreamTerm#slice` to `crystal-rethinkdb`
class RethinkDB::StreamTerm
  def slice(start)
    StreamTerm.new(TermType::SLICE, [self, start])
  end

  def slice(start, size)
    StreamTerm.new(TermType::SLICE, [self, start, size])
  end
end

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
    after_save :cleanup_history

    protected def __create_version__
      return if is_version?

      saved_created = created_at
      saved_updated = updated_at

      @created_at = nil
      @updated_at = nil

      version = self.dup
      version.id = nil
      version.{{ parent_id }} = self.id
      create_version(version).save!

      self.created_at = saved_created
      self.updated_at = saved_updated
    end

    private def cleanup_history
      return if is_version?

      {{ @type }}.table_query do |q|
        associated_version_query(q, &.itself)
          .slice(MAX_VERSIONS)
          .delete
      end
    end

    # Queries
    ###########################################################################

    # Get version history
    #
    # Versions are in descending order of creation
    def history(offset : Int32 = 0, limit : Int32 = 10, &)
      {{ @type }}.raw_query do |r|
        associated_version_query(r.table({{ @type }}.table_name)) do |query_builder|
          (yield query_builder).slice(offset, offset + limit)
        end
      end
    end

    # :ditto:
    def history(offset : Int32 = 0, limit : Int32 = 10)
      history(offset, limit, &.itself)
    end

    # Return the number of versions for the main document.
    #
    # If the document is a version, this is always 0.
    def history_count
      return 0 if is_version?
      {{ @type }}.table_query do |q|
        associated_version_query(q, &.itself).count
      end.as_i
    end

    private def associated_version_query(query_builder)
      query_builder = query_builder
        .get_all([id.as(String)], index: {{ parent_id.symbolize }})
      query_builder = yield query_builder
      query_builder.order_by(r.desc(:created_at))
    end

    # Query on main {{ klass_name }} documents
    #
    # Gets documents where the {{ parent_id }} does not exist, i.e. is the main
    def self.master_{{ klass_name }}_query(offset : Int32 = 0, limit : Int32 = 100)
      raw_query do |q|
        (yield q.table(table_name))
          .filter(&.has_fields({{ parent_id.symbolize }}).not)
          .slice(offset, offset + limit)
      end.to_a
    end

    # Query on main {{ klass_name }} documents
    #
    # Gets documents where the {{ parent_id }} does not exist, i.e. is the main
    def self.master_{{ klass_name }}_raw_query(offset : Int32 = 0, limit : Int32 = 100)
      ::RethinkORM::Connection.raw do |q|
        (yield q.table(table_name))
          .filter(&.has_fields({{ parent_id.symbolize }}).not)
          .slice(offset, offest + limit)
      end
    end
  end
end
