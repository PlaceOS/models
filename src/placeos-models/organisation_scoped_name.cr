require "./base/model"

module PlaceOS::Model
  # Global legacy name validation remains the default. Enable organisation
  # scoping consistently across every model consumer with tenancy enforcement.
  module OrganisationScopedName
    @@enforce : Bool? = nil

    def self.enforce? : Bool
      configured = @@enforce
      return configured unless configured.nil?
      !!ENV["PLACE_TENANCY_ENFORCE"]?.try(&.downcase.in?({"1", "true"}))
    end

    # nil restores the environment default; specs can explicitly override it.
    def self.enforce=(value : Bool?)
      @@enforce = value
    end

    macro ensure_unique_name_within_organisation
      validate :name, "should be unique", ->(this : self) do
        name = this.name.strip
        return true if name.empty?
        this.name = name unless this.persisted?
        query = self.where(name: name)
        query = query.where(organisation_id: this.organisation_id) if OrganisationScopedName.enforce?
        query = query.where("id <> ?", this.id) if this.persisted?
        query.first?.nil?
      end
    end
  end
end
