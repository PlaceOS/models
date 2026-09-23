require "./helper"

private def feature_json(json : String) : Hash(String, Hash(String, JSON::Any))
  Hash(String, Hash(String, JSON::Any)).from_json(json)
end

module PlaceOS::Model
  describe "Group features" do
    Spec.before_each do
      GroupHistory.clear
      GroupInvitation.clear
      GroupZone.clear
      GroupUser.clear
      Group.clear
      User.clear
      Authority.clear
    end

    describe "validation" do
      it "round-trips features through the database" do
        authority = Generator.authority.save!
        group = Generator.group(
          authority: authority,
          subsystems: ["signage"],
          features: feature_json(%({"signage": {"templates": true, "plugins": ["a", "b"], "limits": {"ai": {"daily": 10}}}})),
        ).save!

        found = Group.find!(group.id.not_nil!)
        found.features["signage"]["templates"].as_bool.should be_true
        found.features["signage"]["plugins"].as_a.map(&.as_s).should eq ["a", "b"]
        found.features["signage"]["limits"]["ai"]["daily"].as_i.should eq 10
      end

      it "defaults to no features" do
        authority = Generator.authority.save!
        group = Generator.group(authority: authority).save!
        Group.find!(group.id.not_nil!).features.should be_empty
      end

      it "rejects features for a subsystem the group doesn't participate in" do
        authority = Generator.authority.save!
        group = Generator.group(
          authority: authority,
          subsystems: ["signage"],
          features: feature_json(%({"signage": {"templates": true}, "events": {"catering": true}})),
        )
        group.valid?.should be_false
        group.errors.map(&.field).should contain(:features)
      end

      it "rejects an empty feature key" do
        authority = Generator.authority.save!
        group = Generator.group(
          authority: authority,
          subsystems: ["signage"],
          features: feature_json(%({"signage": {"": true}})),
        )
        group.valid?.should be_false
        group.errors.map(&.field).should contain(:features)
      end

      it "rejects an overly long feature key" do
        authority = Generator.authority.save!
        group = Generator.group(
          authority: authority,
          subsystems: ["signage"],
          features: feature_json(%({"signage": {"#{"k" * 65}": true}})),
        )
        group.valid?.should be_false
        group.errors.map(&.field).should contain(:features)
      end

      it "rejects objects nested more than two levels" do
        authority = Generator.authority.save!
        group = Generator.group(
          authority: authority,
          subsystems: ["signage"],
          features: feature_json(%({"signage": {"deep": {"a": {"b": {"c": 1}}}}})),
        )
        group.valid?.should be_false
        group.errors.map(&.field).should contain(:features)
      end

      it "rejects arrays containing containers" do
        authority = Generator.authority.save!
        group = Generator.group(
          authority: authority,
          subsystems: ["signage"],
          features: feature_json(%({"signage": {"plugins": [{"id": "a"}]}})),
        )
        group.valid?.should be_false
        group.errors.map(&.field).should contain(:features)
      end

      it "records features in history changed_fields" do
        authority = Generator.authority.save!
        actor = Generator.user(authority: authority).save!
        group = Generator.group(authority: authority, subsystems: ["signage"]).save!

        group.acting_user = actor
        group.features = feature_json(%({"signage": {"ai": true}}))
        group.save!

        entry = GroupHistory.where(resource_type: "group", resource_id: group.id.to_s, action: "update").to_a.first
        entry.changed_fields.should contain("features")
      end

      it "features_for returns the group's own subsystem features" do
        authority = Generator.authority.save!
        group = Generator.group(
          authority: authority,
          subsystems: ["signage"],
          features: feature_json(%({"signage": {"ai": true}})),
        )
        group.features_for("signage")["ai"].as_bool.should be_true
        group.features_for("events").should be_empty
      end
    end

    describe "#effective_features" do
      it "returns the root's own features when there are no ancestors" do
        authority = Generator.authority.save!
        root = Generator.group(
          authority: authority,
          subsystems: ["signage"],
          features: feature_json(%({"signage": {"ai": true}})),
        ).save!

        root.effective_features.should eq root.features
      end

      it "inherits a root key down to a grandchild that sets nothing" do
        authority = Generator.authority.save!
        root = Generator.group(authority: authority, subsystems: ["signage"], features: feature_json(%({"signage": {"ai": true}}))).save!
        child = Generator.group(authority: authority, parent: root, subsystems: ["signage"]).save!
        grandchild = Generator.group(authority: authority, parent: child, subsystems: ["signage"]).save!

        grandchild.effective_features("signage")["ai"].as_bool.should be_true
      end

      it "lets a child override a parent key, and the grandchild inherits the override" do
        authority = Generator.authority.save!
        root = Generator.group(authority: authority, subsystems: ["signage"], features: feature_json(%({"signage": {"ai": true, "templates": true}}))).save!
        child = Generator.group(authority: authority, parent: root, subsystems: ["signage"], features: feature_json(%({"signage": {"ai": false}}))).save!
        grandchild = Generator.group(authority: authority, parent: child, subsystems: ["signage"]).save!

        child.effective_features("signage")["ai"].as_bool.should be_false
        grandchild.effective_features("signage")["ai"].as_bool.should be_false
        grandchild.effective_features("signage")["templates"].as_bool.should be_true
        root.effective_features("signage")["ai"].as_bool.should be_true
      end

      it "replaces (rather than unions) a parent's list" do
        authority = Generator.authority.save!
        root = Generator.group(authority: authority, subsystems: ["signage"], features: feature_json(%({"signage": {"plugins": ["a", "b"]}}))).save!
        child = Generator.group(authority: authority, parent: root, subsystems: ["signage"], features: feature_json(%({"signage": {"plugins": ["c"]}}))).save!

        child.effective_features("signage")["plugins"].as_a.map(&.as_s).should eq ["c"]
      end

      it "combines subsystems set on different ancestors" do
        authority = Generator.authority.save!
        root = Generator.group(authority: authority, subsystems: ["signage"], features: feature_json(%({"signage": {"ai": true}}))).save!
        child = Generator.group(authority: authority, parent: root, subsystems: ["events"], features: feature_json(%({"events": {"catering": true}}))).save!
        grandchild = Generator.group(authority: authority, parent: child).save!

        effective = grandchild.effective_features
        effective.keys.sort!.should eq ["events", "signage"]
        effective["signage"]["ai"].as_bool.should be_true
        effective["events"]["catering"].as_bool.should be_true
      end

      it "inherits features for a subsystem the child doesn't participate in" do
        authority = Generator.authority.save!
        root = Generator.group(authority: authority, subsystems: ["signage"], features: feature_json(%({"signage": {"ai": true}}))).save!
        child = Generator.group(authority: authority, parent: root, subsystems: ["events"]).save!

        child.effective_features("signage")["ai"].as_bool.should be_true
      end

      it "never picks up keys set on a sibling or a child" do
        authority = Generator.authority.save!
        root = Generator.group(authority: authority, subsystems: ["signage"]).save!
        a = Generator.group(authority: authority, parent: root, subsystems: ["signage"]).save!
        Generator.group(authority: authority, parent: root, subsystems: ["signage"], features: feature_json(%({"signage": {"sibling": true}}))).save!
        Generator.group(authority: authority, parent: a, subsystems: ["signage"], features: feature_json(%({"signage": {"child": true}}))).save!

        a.effective_features.should be_empty
        root.effective_features.should be_empty
      end

      it "uses unsaved changes on the group itself" do
        authority = Generator.authority.save!
        root = Generator.group(authority: authority, subsystems: ["signage"], features: feature_json(%({"signage": {"ai": true, "templates": true}}))).save!
        child = Generator.group(authority: authority, parent: root, subsystems: ["signage"]).save!

        child.features = feature_json(%({"signage": {"ai": false}}))
        child.effective_features("signage")["ai"].as_bool.should be_false
        child.effective_features("signage")["templates"].as_bool.should be_true
      end

      it "filters by subsystem, returning {} for an unknown one" do
        authority = Generator.authority.save!
        root = Generator.group(authority: authority, subsystems: ["signage", "events"], features: feature_json(%({"signage": {"ai": true}, "events": {"catering": true}}))).save!

        root.effective_features("signage").keys.should eq ["ai"]
        root.effective_features("parking").should be_empty
      end
    end

    describe "#feature?" do
      it "applies truthiness per value type" do
        authority = Generator.authority.save!
        root = Generator.group(
          authority: authority,
          subsystems: ["signage"],
          features: feature_json(%({"signage": {
            "on": true, "off": false,
            "list": ["a"], "empty_list": [],
            "text": "x", "empty_text": "",
            "count": 2, "zero": 0, "float": 0.5, "zero_float": 0.0,
            "obj": {"a": 1}, "empty_obj": {},
            "null": null
          }})),
        ).save!

        child = Generator.group(authority: authority, parent: root, subsystems: ["signage"]).save!

        {"on", "list", "text", "count", "float", "obj"}.each do |key|
          child.feature?("signage", key).should be_true
        end
        {"off", "empty_list", "empty_text", "zero", "zero_float", "empty_obj", "null", "missing"}.each do |key|
          child.feature?("signage", key).should be_false
        end
        child.feature?("events", "on").should be_false
      end
    end
  end
end
