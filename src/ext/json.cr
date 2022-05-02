struct JSON::Any
  # Adheres to JSON Merge Patch RFC7396
  # https://www.rfc-editor.org/rfc/rfc7396.html
  def merge(other : ::JSON::Any, & : (String, JSON::Any) -> JSON::Any?)
    if (hash = @raw).is_a?(Hash(String, Any)) && (other_hash = other.raw).is_a?(Hash(String, Any))
      hash = hash.clone
      other_hash.each do |other_key, other_value|
        other_value = yield(other_key, other_value.clone)

        if other_value.nil? || other_value.raw.nil?
          hash.delete(other_key)
        else
          original_value = hash[other_key]
          hash[other_key] = original_value.merge(other_value)
        end
      end
      JSON::Any.new(hash)
    else
      other.dup
    end
  end

  # :ditto:
  def merge(other : ::JSON::Any)
    merge(other) { |_key, value| value }
  end
end
