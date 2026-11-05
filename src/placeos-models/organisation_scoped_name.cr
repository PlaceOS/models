require "./base/model"

module PlaceOS::Model
  # Name uniqueness for the organisation-owned estate models (zone, system,
  # edge, broker): unique within an organisation, and unique among rows that
  # have no organisation. Backed by the partial unique indexes on
  # (organisation_id, name).
  module OrganisationScopedName
    macro ensure_unique_name_within_organisation
      validate :name, "should be unique within the organisation", ->(this : self) do
        name = this.name.strip
        return true if name.empty?
        this.name = name unless this.persisted?
        existing = self.where(name: name, organisation_id: this.organisation_id).first?
        !(existing && (!this.persisted? || existing.id != this.id))
      end
    end
  end
end
