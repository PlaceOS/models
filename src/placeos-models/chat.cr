require "./base/model"
require "./chat_message"

module PlaceOS::Model
  class Chat < ModelBase
    include PlaceOS::Model::Timestamps
    table :chats

    attribute summary : String

    belongs_to User, foreign_key: "user_id", association_name: "user", presence: true
    belongs_to ControlSystem, foreign_key: "system_id", presence: true

    has_many(
      child_class: ChatMessage,
      foreign_key: "chat_id",
      collection_name: :messages
    )

    validates :user_id, presence: true
    validates :system_id, presence: true
    validates :summary, presence: true
  end
end
