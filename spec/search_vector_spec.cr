require "./helper"

# PPT-2644: generated `search_vector` tsvector columns for PG full-text search.
# The query pattern pinned here (parameterized `to_tsquery('simple', ?)` with
# `:*` prefix tokens joined by `&`) is what rest-api's index routes use.
def vector_search(model, query : String)
  model.where("search_vector @@ to_tsquery('simple', ?)", query).to_a
end

module PlaceOS::Model
  describe "search_vector columns" do
    Spec.after_each do
      Module.clear
      Driver.clear
      ControlSystem.clear
      Zone.clear
      User.clear
      Settings.clear
    end

    it "matches control systems on name, description and features with prefix tokens" do
      cs = Generator.control_system
      cs.name = "Video Conference Alpha"
      cs.description = "boardroom telepresence"
      cs.features = Set{"projector", "whiteboard"}
      cs.save!

      other = Generator.control_system
      other.name = "Lobby Display"
      other.save!

      vector_search(ControlSystem, "video:* & conf:*").map(&.id).should eq [cs.id]
      vector_search(ControlSystem, "telepres:*").map(&.id).should eq [cs.id]
      # array columns (features) are searchable
      vector_search(ControlSystem, "projector:*").map(&.id).should eq [cs.id]
      # ids are searchable (Backoffice sends `id` in every fields list); the
      # "sys" token comes only from the id prefix, so it matches both rows
      vector_search(ControlSystem, "sys:*").size.should eq 2
      vector_search(ControlSystem, "nonexistenttoken:*").should be_empty
    end

    it "matches users on tokenized email but never on secrets" do
      user = Generator.user
      user.email = Email.new("john.doe@example.com")
      user.password_digest = "supersecrethash"
      user.save!

      # split tokens of the email address match…
      vector_search(User, "john:* & doe:*").map(&.id).should eq [user.id]
      vector_search(User, "example:*").map(&.id).should eq [user.id]
      # …and the raw address is kept as a single lexeme too
      vector_search(User, "john.doe@example.com").map(&.id).should eq [user.id]
      # secrets are deliberately not indexed
      vector_search(User, "supersecrethash:*").should be_empty
    end

    it "matches zones on tags" do
      zone = Generator.zone
      zone.name = "Level Three"
      zone.tags = Set{"level", "building-a"}
      zone.save!

      vector_search(Zone, "level:* & building:*").map(&.id).should eq [zone.id]
    end

    it "matches modules on custom name, and drivers on name for join-based search" do
      driver = Generator.driver
      driver.name = "Cisco Video Switcher"
      driver.save!

      mod = Generator.module(driver: driver)
      mod.custom_name = "Projector Left"
      mod.save!

      vector_search(Module, "projector:*").map(&.id).should eq [mod.id]
      # URI/path segments are individually searchable (placeos_fts_uri)
      driver.file_name.as(String).split(/[^A-Za-z0-9]+/).reject(&.empty?).first?.try do |segment|
        vector_search(Driver, "#{segment.downcase}:*").map(&.id).should contain(driver.id)
      end
      # module search by driver name is a query-time join (rest-api concern);
      # the driver side of that join matches here
      vector_search(Driver, "cisco:* & switch:*").map(&.id).should eq [driver.id]

      # the EXISTS pattern rest-api uses for parent-child parity
      Module
        .where(
          "(search_vector @@ to_tsquery('simple', ?) OR EXISTS (SELECT 1 FROM driver d WHERE d.id = driver_id AND d.search_vector @@ to_tsquery('simple', ?)))",
          "cisco:*", "cisco:*"
        ).to_a.map(&.id).should eq [mod.id]
    end

    it "matches settings on keys but not on the settings body" do
      settings = Generator.settings(
        settings_string: %({"api_secret_key": "hunter2"}),
        encryption_level: Encryption::Level::None,
      )
      settings.save!

      # NOTE: Settings versioning writes a history row on save, so match on
      # inclusion rather than equality
      vector_search(Settings, "api_secret_key:*").map(&.id).should contain(settings.id)
      vector_search(Settings, "hunter2:*").should be_empty
    end
  end
end
