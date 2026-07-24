require "json"

require "../base/model"

# forward declare so this file can be required before signage_template.cr
# finishes defining the parent class (the `attribute layouts : Array(Layout)`
# line needs Layout resolved at macro-expansion time).
class PlaceOS::Model::SignageTemplate < ::PgORM::Base; end

module PlaceOS::Model
  struct SignageTemplate::Layout
    include JSON::Serializable

    enum Position
      Top
      Bottom
      Left
      Right
      Floating
    end

    # nil plugin_id means this layout entry is a spacer
    getter plugin_id : String? = nil
    getter position : Position = Position::Top

    # percentages of the screen, exclusive bounds (0, 1).
    # Left/Right slices size via x_pos, Top/Bottom via y_pos,
    # Floating widgets require both.
    getter x_pos : Float32? = nil
    getter y_pos : Float32? = nil

    getter plugin_params : Hash(String, JSON::Any) = {} of String => JSON::Any

    def initialize(
      @position : Position = Position::Top,
      @plugin_id : String? = nil,
      @x_pos : Float32? = nil,
      @y_pos : Float32? = nil,
      @plugin_params : Hash(String, JSON::Any) = {} of String => JSON::Any,
    )
    end

    def spacer? : Bool
      plugin_id.nil?
    end

    # `nil` when the layout is valid, otherwise a human-readable reason.
    def validation_message : String?
      if x = x_pos
        return "x_pos must be greater than 0 and less than 1" unless 0.0_f32 < x < 1.0_f32
      end

      if y = y_pos
        return "y_pos must be greater than 0 and less than 1" unless 0.0_f32 < y < 1.0_f32
      end

      case position
      in .floating?
        return "floating position requires x_pos and y_pos" if x_pos.nil? || y_pos.nil?
      in .left?, .right?
        return "#{position.to_s.downcase} position requires x_pos" if x_pos.nil?
      in .top?, .bottom?
        return "#{position.to_s.downcase} position requires y_pos" if y_pos.nil?
      end

      nil
    end

    def valid? : Bool
      validation_message.nil?
    end
  end
end
