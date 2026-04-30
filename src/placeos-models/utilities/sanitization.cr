require "active-model/sanitizer"

module PlaceOS::Model
  module Sanitization
    extend self

    # Recursively sanitize all string values in a JSON::Any structure
    # to prevent HTML injection (e.g. via extension_data["desk_name"] in email templates)
    def sanitize_json_strings(json : JSON::Any) : JSON::Any
      case raw = json.raw
      when String
        JSON::Any.new(ActiveModel::Sanitizer.text.process(raw))
      when Hash
        sanitized = raw.transform_values { |v| sanitize_json_strings(v) }
        JSON::Any.new(sanitized)
      when Array
        sanitized = raw.map { |v| sanitize_json_strings(v) }
        JSON::Any.new(sanitized)
      else
        json
      end
    end

    # Sanitize all strings in an array, stripping HTML tags
    def sanitize_strings(strings : Array(String)) : Array(String)
      strings.map { |s| ActiveModel::Sanitizer.text.process(s) }
    end

    # Sanitize all strings in a set, stripping HTML tags
    def sanitize_string_set(strings : Set(String)) : Set(String)
      strings.map { |s| ActiveModel::Sanitizer.text.process(s) }.to_set
    end
  end
end
