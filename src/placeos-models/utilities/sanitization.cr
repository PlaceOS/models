require "active-model/sanitizer"

module PlaceOS::Model
  module Sanitization
    extend self

    # Recursively sanitize all string values in a JSON::Any structure
    # to prevent HTML injection (e.g. via extension_data["desk_name"] in email templates).
    #
    # *policy* selects the sanitization level applied to each string value:
    # - `:text`   – strips all HTML tags, returning plain text (default)
    # - `:inline` – preserves inline tags (`<b>`, `<em>`, `<strong>`, `<a>`, …)
    # - `:basic`  – preserves inline tags plus basic block tags (`<p>`, `<h1>`–`<h6>`, `<ul>`, …)
    # - `:common` – preserves most standard HTML tags
    def sanitize_strings(json : JSON::Any, policy : Symbol = :text) : JSON::Any
      case raw = json.raw
      when String
        JSON::Any.new(sanitizer_for(policy).process(raw))
      when Hash
        sanitized = raw.transform_values { |v| sanitize_strings(v, policy) }
        JSON::Any.new(sanitized)
      when Array
        sanitized = raw.map { |v| sanitize_strings(v, policy) }
        JSON::Any.new(sanitized)
      else
        json
      end
    end

    # Sanitize all strings in an array.
    # See `#sanitize_strings(JSON::Any, Symbol)` for *policy* options.
    def sanitize_strings(strings : Array(String), policy : Symbol = :text) : Array(String)
      sanitizer = sanitizer_for(policy)
      strings.map { |s| sanitizer.process(s) }
    end

    # Sanitize all strings in a set.
    # See `#sanitize_strings(JSON::Any, Symbol)` for *policy* options.
    def sanitize_strings(strings : Set(String), policy : Symbol = :text) : Set(String)
      sanitizer = sanitizer_for(policy)
      strings.map { |s| sanitizer.process(s) }.to_set
    end

    private def sanitizer_for(policy : Symbol)
      case policy
      when :text   then ActiveModel::Sanitizer.text
      when :inline then ActiveModel::Sanitizer.inline
      when :basic  then ActiveModel::Sanitizer.basic
      when :common then ActiveModel::Sanitizer.common
      else              raise ArgumentError.new("Unknown sanitization policy: #{policy}")
      end
    end
  end
end
