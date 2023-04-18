# :nodoc:
module PlaceOS::Model::JSONBQuery
  extend self

  alias JKey = JHash | String | Array(Int64)
  alias JHash = Hash(String, JKey)

  def to_query(key : String, value : JKey) : String
    arr2h(k2a(key), value).to_json
  end

  private def arr2h(key : Array(String), value : JKey, idx = 0) : JHash
    h = JHash.new
    if idx == key.size - 1
      h[key[idx]] = value
    else
      h[key[idx]] = arr2h(key, value, idx + 1)
    end
    h
  end

  private def k2a(key : String) : Array(String)
    arr = [] of String
    ignore_next = false
    buff = IO::Memory.new
    key.chars.each do |c|
      if ignore_next
        ignore_next = false
        buff << c
        next
      end

      case c
      when '\\'
        ignore_next = true
      when '.'
        arr << buff.to_s
        buff.clear
      else
        buff << c
      end
    end

    unless buff.empty?
      arr << buff.to_s
    end

    arr
  end
end
