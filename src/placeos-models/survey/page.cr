module PlaceOS::Model
  class Survey < ModelWithAutoKey
    struct Page
      include JSON::Serializable

      property title : String = ""
      property description : String? = nil
      property question_order : Array(Int64) = [] of Int64

      def initialize(@title = "", @description = nil, @question_order = [] of Int64)
      end
    end
  end
end
