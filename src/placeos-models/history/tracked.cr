module PlaceOS::Model
  # Records changes to a model in the `History` table.
  #
  # Creates and updates are captured by pg-orm's `on_persist` hook, after every
  # `before_*` callback and validation have run, so the entry reflects what was
  # written. Deletes are captured by `after_destroy`. Entries are written in the
  # same transaction as the change.
  #
  # ```
  # class Zone < ModelBase
  #   include History::Tracked
  #
  #   history_ignore :last_seen
  #   history_redact :secret
  # end
  # ```
  #
  # Override `history_resource_id`, `history_correlation_id` or
  # `history_record_as` to customise what is recorded.
  module History::Tracked
    REDACTED = JSON::Any.new("[REDACTED]")

    macro included
      # Request details recorded with changes to this record, defaults to
      # `History.current_metadata`
      @[JSON::Field(ignore: true)]
      @[YAML::Field(ignore: true)]
      property history_metadata : ::PlaceOS::Model::History::Metadata? = nil

      # Overrides the action recorded by the next change, e.g. `approve`
      @[JSON::Field(ignore: true)]
      @[YAML::Field(ignore: true)]
      property history_action : String? = nil

      after_destroy :__record_history_destroy__

      # Fields not recorded, changes to only these fields are not recorded at all
      def self.history_ignored : Array(String)
        ["created_at", "updated_at"]
      end

      # Fields whose values are never recorded
      def self.history_redacted : Array(String)
        [] of String
      end

      # Entries recorded for the resource, newest first
      def self.change_history(resource_id : String)
        ::PlaceOS::Model::History.for_resource(table_name, resource_id)
      end

      # Recreates a deleted record from its latest `delete` entry, keeping its id.
      #
      # Records removed alongside it (cascading deletes) are not restored and
      # redacted fields are left at their defaults. Raises if there is no
      # delete entry or the record can't be saved, e.g. if it already exists.
      def self.undelete(resource_id : String) : self
        entry = change_history(resource_id).where(action: "delete").first?
        snapshot = entry.try(&.snapshot).try { |json| json unless json.raw.nil? }
        raise ::PgORM::Error::RecordNotFound.new("no deleted #{table_name} #{resource_id} in history") unless snapshot

        record = from_trusted_json(snapshot.to_json)
        record.history_action = "restore"
        record.save!
        record
      end
    end

    # Fields not recorded, changes to only these fields are not recorded at all
    macro history_ignore(*fields)
      def self.history_ignored : Array(String)
        previous_def + [{{ fields.map(&.id.stringify).splat }}]
      end
    end

    # Fields whose values are never recorded
    macro history_redact(*fields)
      def self.history_redacted : Array(String)
        previous_def + [{{ fields.map(&.id.stringify).splat }}]
      end
    end

    # Entries recorded for this record, newest first
    def change_history
      ::PlaceOS::Model::History.for_resource(self.class.table_name, history_resource_id)
    end

    # Identifies the record in history, composite keys are joined with `:`
    def history_resource_id : String
      case key = id
      when Tuple
        key.join(':')
      else
        key.to_s
      end
    end

    # A parent the change should also be found under
    def history_correlation_id : String?
      nil
    end

    # The action to record for a `create`, `update` or `delete`, or nil to skip it
    protected def history_record_as(action : String) : String?
      history_action || action
    end

    # Fields listed as changed, from the `{"field": [previous, current]}` diff
    protected def history_changed_fields(diff : Hash(String, JSON::Any)) : Array(String)
      diff.keys
    end

    # Actions that store the full record
    protected def history_snapshot?(action : String) : Bool
      action.in?("delete", "approve")
    end

    protected def on_persist(created : Bool) : Nil
      super
      action = history_record_as(created ? "create" : "update")
      self.history_action = nil
      return unless action

      diff = history_diff(created)
      return if diff.empty? && !created
      __record_history__(action, diff)
    end

    protected def __record_history_destroy__
      action = history_record_as("delete")
      self.history_action = nil
      __record_history__(action) if action
    end

    # Persisted changes as `{"field": [previous, current]}`, without ignored
    # fields and with redacted values replaced. Creates include every field set.
    protected def history_diff(created : Bool = false) : Hash(String, JSON::Any)
      changes = if created
                  JSON.parse(attributes_json).as_h.compact_map do |field, value|
                    {field, JSON::Any.new([JSON::Any.new(nil), value])} unless value.raw.nil?
                  end.to_h
                else
                  JSON.parse(changes_json).as_h
                end

      ignored = self.class.history_ignored
      redacted = self.class.history_redacted
      diff = {} of String => JSON::Any
      changes.each do |field, change|
        next if ignored.includes?(field)
        diff[field] = redacted.includes?(field) ? JSON::Any.new([REDACTED, REDACTED]) : change
      end
      diff
    end

    # The record's attributes, without redacted fields
    protected def history_snapshot : JSON::Any
      redacted = self.class.history_redacted
      JSON::Any.new(JSON.parse(attributes_json).as_h.reject! { |field, _| redacted.includes?(field) })
    end

    private def __record_history__(action : String, diff = {} of String => JSON::Any) : Nil
      ::PlaceOS::Model::History.record_change(
        resource_type: self.class.table_name,
        resource_id: history_resource_id,
        correlation_id: history_correlation_id,
        action: action,
        changed_fields: history_changed_fields(diff),
        diff: diff,
        snapshot: history_snapshot?(action) ? history_snapshot : nil,
        metadata: history_metadata,
      )
    end
  end
end
