require "./helper"

module PlaceOS::Model
  describe Metadata do
    test_round_trip(Metadata)

    it "saves control_system metadata" do
      control_system = Generator.control_system.save!
      meta = Generator.metadata(name: "test", parent: control_system.id.as(String)).save!

      control_system.metadata.first.id.should eq meta.id

      meta_find = Metadata.find!(meta.id.as(String))
      meta_find.control_system!.id.should eq control_system.id

      control_system.destroy
    end

    it "`modifying_user_id` is `nil` if modifying user is not recorded" do
      modifier = Generator.user.save!
      control_system = Generator.control_system.save!
      model = Metadata.new(name: "test")
      model.details = JSON::Any.new({} of String => JSON::Any)
      model.control_system = control_system
      model.modified_by = modifier
      model.save
      model.modified_by_id.should eq(modifier.id)
      model.details_will_change!
      model.save
      model.modified_by_id.should be_nil
    end

    it "saves zone metadata" do
      zone = Generator.zone.save!
      meta = Generator.metadata(parent: zone.id.as(String)).save!

      zone.metadata.first.id.should eq meta.id
      meta_find = Metadata.find!(meta.id.as(String))
      meta_find.zone!.id.should eq zone.id

      zone.destroy
    end

    describe "#details" do
      it "serializes field to a JSON object" do
        object = %({"hello":"world"})
        meta = Metadata.new(
          name: "hello",
          description: "",
          details: JSON.parse(object),
          parent_id: "1234",
          editors: Set(String).new,
        )

        # Satisfies round trip property
        Metadata.from_json(meta.to_json).details.should eq JSON.parse(object)
      end

      context "JSON Merge Patch" do
        it "deep merges objects" do
          a = {
            hello: :world,
            a:     {aa: {aaa: 1}},
            b:     {bb: 1},
          }

          b = {
            hello: :friend,
            a:     {aa: {bbb: 2}},
            b:     {bb: 2},
            c:     1,
          }

          b_into_a = {
            hello: :friend,
            a:     {aa: {aaa: 1, bbb: 2}},
            b:     {bb: 2},
            c:     1,
          }

          a_into_b = {
            hello: :world,
            a:     {aa: {aaa: 1, bbb: 2}},
            b:     {bb: 1},
            c:     1,
          }

          json = {a, b, a_into_b, b_into_a}.map { |o| JSON.parse(o.to_json) }
          json_a, json_b, json_a_into_b, json_b_into_a = json

          json_a.merge(json_b).should eq(json_b_into_a)
          json_b.merge(json_a).should eq(json_a_into_b)
        end

        it "deletes keys for which new value is `null`" do
          a, b = { {a: 1}, {a: nil} }.map { |o| JSON.parse(o.to_json) }
          a.merge(b).as_h.has_key?("a").should be_false
        end

        it "replaces self with other if either are not an object" do
          json = [{a: 1}, 1, 1.5, true, nil, [1]].map { |o| JSON.parse(o.to_json) }
          a = json.shift
          json.each do |b|
            a.merge(b).should eq(b)
            b.merge(a).should eq(a)
          end
        end
      end
    end

    context "validation" do
      it "ensures `name` is unique beneath `parent_id`, ignoring versions" do
        parent = Generator.zone.save!
        parent_id = parent.id.as(String)
        name = Time.utc.to_unix_f.to_s
        original, duplicate = Array(Metadata).new(2) { Generator.metadata(name: name, parent: parent_id) }
        original.save!

        expect_raises(RethinkORM::Error::DocumentInvalid, /`name` must be unique beneath 'parent_id'/) do
          duplicate.save!
        end
      end

      it "ensures `parent_id` exists" do
        parent_id = "zone-doesnotexist"
        metadata = Generator.metadata(parent: parent_id)

        expect_raises(RethinkORM::Error::DocumentInvalid, /`parent_id` must reference an existing model/) do
          metadata.save!
        end
      end
    end

    describe "#history_count" do
      it "returns 0 for versions" do
        changes = [0, 1].map { |i| JSON::Any.new({"test" => JSON::Any.new(i.to_i64)}) }
        metadata = Generator.metadata
        metadata.details = changes.first
        metadata.save!

        changes[1..].each_with_index(offset: 1) do |detail, i|
          Timecop.freeze(i.seconds.from_now) do
            metadata.details = detail
            metadata.save!
          end
        end

        metadata.history.first.history_count.should eq 0
      end

      it "returns count of versions for main document" do
        changes = [0, 1, 2, 3].map { |i| JSON::Any.new({"test" => JSON::Any.new(i.to_i64)}) }
        metadata = Generator.metadata
        metadata.details = changes.first
        metadata.save!

        changes[1..].each_with_index(offset: 1) do |detail, i|
          Timecop.freeze(i.seconds.from_now) do
            metadata.details = detail
            metadata.save!
          end
        end

        metadata.history_count.should eq changes.size
      end
    end

    describe "#history" do
      it "renders versions made on updates to the master Metadata" do
        changes = [0, 1, 2, 3].map { |i| JSON::Any.new({"test" => JSON::Any.new(i.to_i64)}) }
        metadata = Generator.metadata
        metadata.details = changes.first
        metadata.save!

        changes[1..].each_with_index(offset: 1) do |detail, i|
          Timecop.freeze(i.seconds.from_now) do
            metadata.details = detail
            metadata.save!
          end
        end

        metadata.history.map(&.details.as_h["test"]).should eq [3, 2, 1, 0]
      end

      it "limits number of stored versions" do
        changes = Array(JSON::Any).new(2 * Utilities::Versions::MAX_VERSIONS) { |i|
          JSON::Any.new({"test" => JSON::Any.new(i.to_i64)})
        }

        metadata = Generator.metadata
        metadata.details = changes.first
        metadata.save!

        changes[1..].each_with_index(offset: 1) do |detail, i|
          Timecop.freeze(i.seconds.from_now) do
            metadata.details = detail
            metadata.save!
          end
        end

        metadata.history(limit: 2).size.should eq 2
        metadata.history(limit: 1000).size.should eq Utilities::Versions::MAX_VERSIONS
      end
    end
  end

  describe ".query" do
    it "paginates" do
      name = Time.utc.to_unix_f.to_s

      expected = 10
      model_ids = Array(String).new(size: expected) { Generator.metadata(name: name).save!.id.as(String) }.sort

      Metadata.query([Metadata::Query::Name.new(name)], limit: 1).size.should eq(1)

      first_query = Metadata.query([Metadata::Query::Name.new(name)], limit: 5)
      last_query = Metadata.query([Metadata::Query::Name.new(name)], offset: 5)

      first_query
        .concat(last_query)
        .map(&.id.as(String))
        .sort!
        .should eq(model_ids)
    end

    Metadata::Query::Type.each do |type|
      before_all { Metadata.clear }
      describe type do
        case type
        in .name?
          it "filters by Metadata `name`" do
            name = Time.utc.to_unix_f.to_s
            expected = 2
            expected.times { Generator.metadata(name: name).save! }
            5.times { Generator.metadata.save! }

            Metadata
              .query([Metadata::Query::Name.new(name)])
              .tap(&.size.should eq(expected))
              .all?(&.name.==(name)).should be_true
          end
        in .association?
          before_all do
            models = {Generator.control_system, Generator.zone, Generator.user}.tap &.each(&.save!)
            _metadatas = models.map { |model| Generator.metadata(parent: model.id.as(String)).save! }
          end

          Metadata::Query::Association::Type.each do |association|
            it "filters by #{association}" do
              Metadata
                .query([Metadata::Query::Association.new(association)])
                .tap(&.should_not be_empty)
                .all?(&.parent_id.not_nil!.starts_with?(association.id_prefix))
                .should be_true
            end
          end
        in .key_missing?
          before_all do
            Metadata.clear
            mock_value = Time.utc.to_unix_f.to_s
            mock_details = {
              {
                "one" => mock_value,
              },
              {
                "one" => {"two" => mock_value},
              },
            }

            mock_details.each do |details|
              meta = Generator.metadata
              meta.details = JSON.parse(details.to_json)
              meta.save!
            end
          end

          it "checks for missing keys, where values can be objects" do
            Metadata
              .query([Metadata::Query::KeyMissing.new("one")])
              .size.should eq(0)
          end

          it "checks for missing keys of depth 2" do
            Metadata
              .query([Metadata::Query::KeyMissing.new("one.two")])
              .size.should eq(1)
          end

          it "checks for keys that are entirely missing" do
            Metadata
              .query([Metadata::Query::KeyMissing.new("two")])
              .size.should eq(2)
          end
        in .equals?
          key_paths = {"one", "one.two"}
          mock_value = "#{Time.utc.to_unix_ms}@evil.corp"
          before_all do
            mock_details = {
              {
                "one" => mock_value,
              },
              {
                "one" => {"two" => mock_value},
              },
            }

            mock_details.each do |details|
              meta = Generator.metadata
              meta.details = JSON.parse(details.to_json)
              meta.save!
            end
          end

          key_paths.each_with_index(offset: 1) do |path, depth|
            it "matches values at key depth of #{depth}" do
              # Ensure that queries with URI encoded values work
              query = Metadata::Query.from_param?("equals[#{path}]", URI.encode_www_form(mock_value)).not_nil!
              Metadata
                .query([query])
                .tap(&.size.should eq(1))
                .first.tap do |metadata|
                path.split('.').reduce(metadata.details) do |object, key|
                  object.as_h[key]
                end.should eq(mock_value)
              end
            end
          end
        in .starts_with?
          key_paths = {"one", "one.two"}
          mock_value = "^.#{UUID.random}"

          before_all do
            mock_details = {
              {
                "one" => mock_value,
              },
              {
                "one" => {"two" => mock_value},
              },
            }

            mock_details.each do |details|
              meta = Generator.metadata
              meta.details = JSON.parse(details.to_json)
              meta.save!
            end
          end

          key_paths.each_with_index(offset: 1) do |path, depth|
            it "matches the start of values at key depth of #{depth}" do
              Metadata
                .query([Metadata::Query::StartsWith.new(path, mock_value[..mock_value.size//2])])
                .tap(&.size.should eq(1))
                .first.tap do |metadata|
                path.split('.').reduce(metadata.details) do |object, key|
                  object.as_h[key]
                end.should eq(mock_value)
              end
            end
          end
        end
      end
    end
  end

  describe Metadata::Query do
    describe ".from_param?" do
      Metadata::Query::Type.each do |type|
        describe type do
          case type
          in .name?
            it "doesn't expect a key" do
              Metadata::Query.from_param?("name[uh-oh]", "system")
                .should be_nil

              Metadata::Query.from_param?("name", "system")
                .tap(&.should_not be_nil)
                .not_nil!
                .should be_a Metadata::Query::Name
            end
          in .association?
            it "doesn't expect a key" do
              Metadata::Query.from_param?("association[uh-oh]", "system")
                .should be_nil
            end

            it "expects a valid association" do
              Metadata::Query.from_param?("association", "system")
                .tap(&.should_not be_nil)
                .not_nil!
                .should be_a Metadata::Query::Association

              Metadata::Query.from_param?("association", "foot")
                .should be_nil
            end
          in .key_missing?
            it "expects a key" do
              Metadata::Query.from_param?("key_missing", nil)
                .should be_nil

              Metadata::Query.from_param?("key_missing[uh-oh]", nil)
                .should be_a Metadata::Query::KeyMissing
            end

            it "doesn't expect a value" do
              Metadata::Query.from_param?("key_missing[uh-oh]", "something")
                .should be_nil
            end
          in .equals?
            it "expects a key" do
              Metadata::Query.from_param?("equals", "foo")
                .should be_nil
            end
          in .starts_with?
            it "expects a key" do
              Metadata::Query.from_param?("starts_with", "foo")
                .should be_nil
            end
          end
        end
      end
    end
  end

  describe ".for" do
    it "fetches metadata for a parent" do
      parent = Generator.zone.save!
      parent_id = parent.id.as(String)
      5.times do
        Generator.metadata(parent: parent_id).save!
      end
      Metadata.for(parent_id).to_a.size.should eq 5
      parent.destroy
    end
  end

  describe "#assign_from_interface" do
    it "updates a metadata from an interface" do
      interface = Metadata::Interface.new(
        description: "hello",
        name: "jeff",
        details: JSON.parse("{}"),
        parent_id: "zone-doesntexist",
      )
      metadata = Generator.metadata
      metadata.assign_from_interface(Generator.user_jwt(permission: :admin_support), interface)

      # `parent_id` remains unchanged
      metadata.parent_id.should_not eq interface.parent_id
      # `name` remains unchanged
      metadata.name.should_not eq interface.name

      metadata.description.should eq interface.description
      metadata.details.should eq interface.details
    end
  end

  describe ".from_interface" do
    it "builds a metadata from an interface" do
      interface = Metadata::Interface.new(
        description: "hello",
        name: "jeff",
        details: JSON.parse("{}"),
        parent_id: "zone-doesntexist",
      )
      Metadata.from_interface(interface)
    end
  end

  describe ".build_metadata" do
    it "builds a response of metadata for a parent" do
      parent = Generator.zone.save!
      parent_id = parent.id.as(String)
      5.times do
        Generator.metadata(parent: parent_id).save!
      end
      Metadata.build_metadata(parent_id).size.should eq 5
      parent.destroy
    end
  end

  describe ".build_history" do
    it "builds a response of metadata history for a parent" do
      parent = Generator.zone.save!
      parent_id = parent.id.as(String)
      changes = [0, 1, 2, 3, 4].map { |i| JSON::Any.new({"test" => JSON::Any.new(i.to_i64)}) }

      4.times do |index|
        metadata = Generator.metadata(parent: parent_id)
        metadata.details = changes.first
        metadata.save!
        changes[1..(index + 1)].each_with_index(offset: 1) do |detail, i|
          Timecop.freeze(i.seconds.from_now) do
            metadata.details = detail
            metadata.save!
          end
        end
      end

      history = Metadata.build_history(parent_id)
      history.size.should eq 4
      history.values.map(&.map(&.details["test"].as_i)).sort_by!(&.size).should eq [
        [1, 0],
        [2, 1, 0],
        [3, 2, 1, 0],
        [4, 3, 2, 1, 0],
      ]
      parent.destroy
    end
  end
end
