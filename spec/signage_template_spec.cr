require "./helper"

module PlaceOS::Model
  describe SignageTemplate do
    Spec.before_each do
      SignageTemplate::SystemTemplate.clear
      SignageTemplate.clear
      SignagePlugin.clear
      Playlist::Item.clear
      History.clear
    end

    test_round_trip(SignageTemplate)

    it "creates a template and reloads its layouts" do
      widget = Generator.widget_plugin.save!
      layouts = [
        Generator.layout(plugin: widget, position: SignageTemplate::Layout::Position::Left, x_pos: 0.3_f32, y_pos: nil),
        Generator.layout(position: SignageTemplate::Layout::Position::Floating, x_pos: 0.5_f32, y_pos: 0.75_f32),
      ]
      template = Generator.signage_template(layouts: layouts, tags: ["lobby", "level1"]).save!

      found = SignageTemplate.find!(template.id.as(UUID))
      found.name.should eq template.name
      found.tags.should eq ["lobby", "level1"]
      found.full_screen_takeover.should eq false
      found.layouts.size.should eq 2

      slice = found.layouts[0]
      slice.plugin_id.should eq widget.id
      slice.position.should eq SignageTemplate::Layout::Position::Left
      slice.x_pos.should eq 0.3_f32
      slice.spacer?.should eq false

      floating = found.layouts[1]
      floating.plugin_id.should be_nil
      floating.spacer?.should eq true
      floating.x_pos.should eq 0.5_f32
      floating.y_pos.should eq 0.75_f32
    end

    it "requires a name" do
      template = Generator.signage_template(name: "")
      template.save.should eq false
      template.errors.map(&.field).should contain :name
    end

    it "requires an authority" do
      template = SignageTemplate.new
      template.name = "no authority"
      template.save.should eq false
      template.errors.map(&.field).should contain :authority_id
    end

    describe "layout structural validation" do
      it "requires x_pos and y_pos for floating layouts" do
        layout = Generator.layout(position: SignageTemplate::Layout::Position::Floating, x_pos: 0.5_f32, y_pos: nil)
        template = Generator.signage_template(layouts: [layout])
        template.save.should eq false
        template.errors.first.field.should eq :layouts
        template.errors.first.message.should contain "floating"
      end

      it "requires x_pos for left and right layouts" do
        {SignageTemplate::Layout::Position::Left, SignageTemplate::Layout::Position::Right}.each do |position|
          layout = Generator.layout(position: position, x_pos: nil, y_pos: nil)
          template = Generator.signage_template(layouts: [layout])
          template.save.should eq false
          template.errors.first.field.should eq :layouts
          template.errors.first.message.should contain "requires x_pos"
        end
      end

      it "requires y_pos for top and bottom layouts" do
        {SignageTemplate::Layout::Position::Top, SignageTemplate::Layout::Position::Bottom}.each do |position|
          layout = Generator.layout(position: position, y_pos: nil)
          template = Generator.signage_template(layouts: [layout])
          template.save.should eq false
          template.errors.first.field.should eq :layouts
          template.errors.first.message.should contain "requires y_pos"
        end
      end

      it "requires positions to be percentages between 0 and 1 exclusive" do
        {0.0_f32, 1.0_f32, -0.5_f32, 1.5_f32}.each do |value|
          layout = Generator.layout(position: SignageTemplate::Layout::Position::Top, y_pos: value)
          template = Generator.signage_template(layouts: [layout])
          template.save.should eq false
          template.errors.first.field.should eq :layouts
          template.errors.first.message.should contain "y_pos"
        end
      end

      it "accepts a spacer layout without a plugin" do
        layout = Generator.layout(position: SignageTemplate::Layout::Position::Bottom, y_pos: 0.2_f32)
        template = Generator.signage_template(layouts: [layout])
        template.save.should eq true
      end
    end

    describe "layout plugin validation" do
      it "rejects layouts referencing a plugin that does not exist" do
        layout = SignageTemplate::Layout.new(plugin_id: "signage_plugin-nonexistent", y_pos: 0.25_f32)
        template = Generator.signage_template(layouts: [layout])
        template.save.should eq false
        template.errors.first.field.should eq :layouts
        template.errors.first.message.should contain "does not exist"
      end

      it "rejects layouts referencing a non-widget plugin" do
        plugin = Generator.signage_plugin.save!
        layout = Generator.layout(plugin: plugin)
        template = Generator.signage_template(layouts: [layout])
        template.save.should eq false
        template.errors.first.field.should eq :layouts
        template.errors.first.message.should contain "not a widget"
      end

      it "rejects widgets belonging to a different authority" do
        other_authority = Generator.authority(domain: "http://other.example.com").save!
        widget = Generator.widget_plugin(authority: other_authority).save!
        layout = Generator.layout(plugin: widget)
        template = Generator.signage_template(layouts: [layout])
        template.save.should eq false
        template.errors.first.field.should eq :layouts
        template.errors.first.message.should contain "same authority"
      end

      it "rejects params that do not exist in the plugin properties" do
        widget = Generator.widget_plugin.save!
        layout = Generator.layout(plugin: widget, plugin_params: {"bogus" => JSON::Any.new("value")})
        template = Generator.signage_template(layouts: [layout])
        template.save.should eq false
        template.errors.first.field.should eq :layouts
        template.errors.first.message.should contain "'bogus'"
      end

      it "enforces required params" do
        widget = Generator.widget_plugin(
          params: {
            "type"       => JSON::Any.new("object"),
            "properties" => JSON::Any.new({
              "api_key" => JSON::Any.new({"type" => JSON::Any.new("string")} of String => JSON::Any),
            } of String => JSON::Any),
            "required" => JSON::Any.new([JSON::Any.new("api_key")]),
          },
          defaults: {} of String => JSON::Any,
        ).save!

        layout = Generator.layout(plugin: widget)
        template = Generator.signage_template(layouts: [layout])
        template.save.should eq false
        template.errors.first.field.should eq :layouts
        template.errors.first.message.should contain "required param 'api_key'"

        layout = Generator.layout(plugin: widget, plugin_params: {"api_key" => JSON::Any.new("secret")})
        template = Generator.signage_template(layouts: [layout])
        template.save.should eq true
      end

      it "satisfies required params via plugin defaults" do
        widget = Generator.widget_plugin(
          params: {
            "type"       => JSON::Any.new("object"),
            "properties" => JSON::Any.new({
              "api_key" => JSON::Any.new({"type" => JSON::Any.new("string")} of String => JSON::Any),
            } of String => JSON::Any),
            "required" => JSON::Any.new([JSON::Any.new("api_key")]),
          },
          defaults: {"api_key" => JSON::Any.new("default-secret")},
        ).save!

        layout = Generator.layout(plugin: widget)
        template = Generator.signage_template(layouts: [layout])
        template.save.should eq true
      end
    end

    describe "history recording" do
      it "does not record history on create" do
        Generator.signage_template.save!
        History.count.should eq 0
      end

      it "records changed fields on update" do
        template = Generator.signage_template.save!

        template.name = "updated name"
        template.tags = ["new-tag"]
        template.save!

        History.count.should eq 1
        history = History.all.to_a.first
        history.type.should eq "template"
        history.resource_id.should eq template.id.to_s
        history.action.should eq "updated"
        history.changed_fields.should eq ["name", "tags"]
      end

      it "records layout changes" do
        template = Generator.signage_template.save!

        template.layouts = [Generator.layout]
        template.save!

        History.count.should eq 1
        History.all.to_a.first.changed_fields.should eq ["layouts"]
      end

      it "does not record history when nothing changed" do
        template = Generator.signage_template.save!
        template.save!
        History.count.should eq 0
      end
    end

    it "clears background_item_id when the media item is deleted" do
      item = Generator.item.save!
      template = Generator.signage_template
      template.background_item_id = item.id
      template.save!

      item.destroy

      found = SignageTemplate.find!(template.id.as(UUID))
      found.background_item_id.should be_nil
    end

    it "is removed when the authority is deleted" do
      authority = Generator.authority(domain: "http://cascade.example.com").save!
      template = Generator.signage_template(authority: authority).save!
      template_id = template.id.as(UUID)

      authority.destroy
      SignageTemplate.find?(template_id).should be_nil
    end

    it "supports filtering by tag" do
      Generator.signage_template(tags: ["lobby"]).save!
      Generator.signage_template(tags: ["carpark"]).save!

      SignageTemplate.where("? = ANY(tags)", "lobby").count.should eq 1
    end
  end
end
