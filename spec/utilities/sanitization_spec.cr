require "spec"
require "../../src/placeos-models/utilities/sanitization"

module PlaceOS::Model
  describe Sanitization, tags: "sanitization" do
    describe ".sanitize_strings(JSON::Any)" do
      it "strips HTML tags from string values" do
        json = JSON.parse(%({ "name": "<script>alert('xss')</script>Hello" }))
        result = Sanitization.sanitize_strings(json)
        result["name"].as_s.should eq "Hello"
      end

      it "recursively sanitizes nested hashes" do
        json = JSON.parse(%({
          "level1": {
            "level2": "<b>bold</b> text"
          }
        }))
        result = Sanitization.sanitize_strings(json)
        result["level1"]["level2"].as_s.should eq "bold text"
      end

      it "recursively sanitizes arrays" do
        json = JSON.parse(%({
          "items": ["<em>italic</em>", "<div>block</div>"]
        }))
        result = Sanitization.sanitize_strings(json)
        result["items"][0].as_s.should eq "italic"
        result["items"][1].as_s.should eq "block"
      end

      it "preserves non-string values" do
        json = JSON.parse(%({
          "count": 42,
          "active": true,
          "rate": 3.14,
          "nothing": null
        }))
        result = Sanitization.sanitize_strings(json)
        result["count"].as_i.should eq 42
        result["active"].as_bool.should be_true
        result["rate"].as_f.should eq 3.14
        result["nothing"].raw.should be_nil
      end

      it "handles deeply nested mixed structures" do
        json = JSON.parse(%({
          "data": {
            "users": [
              { "name": "<img src=x onerror=alert(1)>John" },
              { "name": "Jane" }
            ],
            "count": 2
          }
        }))
        result = Sanitization.sanitize_strings(json)
        result["data"]["users"][0]["name"].as_s.should eq "John"
        result["data"]["users"][1]["name"].as_s.should eq "Jane"
        result["data"]["count"].as_i.should eq 2
      end

      it "returns clean strings unchanged" do
        json = JSON.parse(%({ "name": "clean text" }))
        result = Sanitization.sanitize_strings(json)
        result["name"].as_s.should eq "clean text"
      end

      it "handles empty objects and arrays" do
        json = JSON.parse(%({ "empty_obj": {}, "empty_arr": [] }))
        result = Sanitization.sanitize_strings(json)
        result["empty_obj"].as_h.should be_empty
        result["empty_arr"].as_a.should be_empty
      end

      it "preserves inline tags when using the :inline policy" do
        json = JSON.parse(%({ "body": "<b>bold</b> and <em>italic</em>" }))
        result = Sanitization.sanitize_strings(json, :inline)
        result["body"].as_s.should eq "<b>bold</b> and <em>italic</em>"
      end

      it "still strips non-inline tags when using the :inline policy" do
        json = JSON.parse(%({ "body": "<p><script>xss</script>safe</p>" }))
        result = Sanitization.sanitize_strings(json, :inline)
        result["body"].as_s.should eq "safe"
      end

      it "recursively applies the policy to nested structures" do
        json = JSON.parse(%({
          "items": ["<b>bold</b>", "<p>paragraph</p>"]
        }))
        result = Sanitization.sanitize_strings(json, :inline)
        result["items"][0].as_s.should eq "<b>bold</b>"
        result["items"][1].as_s.should eq "paragraph"
      end
    end

    describe ".sanitize_strings(Array(String))" do
      it "strips HTML tags from all strings in an array" do
        input = ["<b>bold</b>", "plain", "<script>xss</script>safe"]
        result = Sanitization.sanitize_strings(input)
        result.should eq ["bold", "plain", "safe"]
      end

      it "handles an empty array" do
        result = Sanitization.sanitize_strings([] of String)
        result.should be_empty
      end

      it "returns clean strings unchanged" do
        input = ["hello", "world"]
        result = Sanitization.sanitize_strings(input)
        result.should eq ["hello", "world"]
      end

      it "preserves inline tags when using the :inline policy" do
        input = ["<b>bold</b>", "<em>italic</em>", "<p>paragraph</p>"]
        result = Sanitization.sanitize_strings(input, :inline)
        result.should eq ["<b>bold</b>", "<em>italic</em>", "paragraph"]
      end
    end

    describe ".sanitize_strings(Set(String))" do
      it "strips HTML tags from all strings in a set" do
        input = Set{"<b>bold</b>", "plain"}
        result = Sanitization.sanitize_strings(input)
        result.should contain("bold")
        result.should contain("plain")
        result.should_not contain("<b>bold</b>")
      end

      it "handles an empty set" do
        result = Sanitization.sanitize_strings(Set(String).new)
        result.should be_empty
      end

      it "returns clean strings unchanged" do
        input = Set{"hello", "world"}
        result = Sanitization.sanitize_strings(input)
        result.should eq Set{"hello", "world"}
      end

      it "preserves inline tags when using the :inline policy" do
        input = Set{"<b>bold</b>", "<p>paragraph</p>"}
        result = Sanitization.sanitize_strings(input, :inline)
        result.should contain("<b>bold</b>")
        result.should contain("paragraph")
        result.should_not contain("<p>paragraph</p>")
      end
    end
  end
end
