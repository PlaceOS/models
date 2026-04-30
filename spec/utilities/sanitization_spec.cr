require "spec"
require "../../src/placeos-models/utilities/sanitization"

module PlaceOS::Model
  describe Sanitization, tags: "sanitization" do
    describe ".sanitize_json_strings" do
      it "strips HTML tags from string values" do
        json = JSON.parse(%({ "name": "<script>alert('xss')</script>Hello" }))
        result = Sanitization.sanitize_json_strings(json)
        result["name"].as_s.should eq "alert('xss')Hello"
      end

      it "recursively sanitizes nested hashes" do
        json = JSON.parse(%({
          "level1": {
            "level2": "<b>bold</b> text"
          }
        }))
        result = Sanitization.sanitize_json_strings(json)
        result["level1"]["level2"].as_s.should eq "bold text"
      end

      it "recursively sanitizes arrays" do
        json = JSON.parse(%({
          "items": ["<em>italic</em>", "<div>block</div>"]
        }))
        result = Sanitization.sanitize_json_strings(json)
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
        result = Sanitization.sanitize_json_strings(json)
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
        result = Sanitization.sanitize_json_strings(json)
        result["data"]["users"][0]["name"].as_s.should eq "John"
        result["data"]["users"][1]["name"].as_s.should eq "Jane"
        result["data"]["count"].as_i.should eq 2
      end

      it "returns clean strings unchanged" do
        json = JSON.parse(%({ "name": "clean text" }))
        result = Sanitization.sanitize_json_strings(json)
        result["name"].as_s.should eq "clean text"
      end

      it "handles empty objects and arrays" do
        json = JSON.parse(%({ "empty_obj": {}, "empty_arr": [] }))
        result = Sanitization.sanitize_json_strings(json)
        result["empty_obj"].as_h.should be_empty
        result["empty_arr"].as_a.should be_empty
      end
    end

    describe ".sanitize_strings" do
      it "strips HTML tags from all strings in an array" do
        input = ["<b>bold</b>", "plain", "<script>xss</script>safe"]
        result = Sanitization.sanitize_strings(input)
        result.should eq ["bold", "plain", "xsssafe"]
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
    end

    describe ".sanitize_string_set" do
      it "strips HTML tags from all strings in a set" do
        input = Set{"<b>bold</b>", "plain"}
        result = Sanitization.sanitize_string_set(input)
        result.should contain("bold")
        result.should contain("plain")
        result.should_not contain("<b>bold</b>")
      end

      it "handles an empty set" do
        result = Sanitization.sanitize_string_set(Set(String).new)
        result.should be_empty
      end

      it "returns clean strings unchanged" do
        input = Set{"hello", "world"}
        result = Sanitization.sanitize_string_set(input)
        result.should eq Set{"hello", "world"}
      end
    end
  end
end
