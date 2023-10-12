require "./helper"

module PlaceOS::Model
  describe Chat do
    Spec.before_each do
      ChatMessage.clear
      Chat.clear
    end

    test_round_trip(Chat)
    test_round_trip(ChatMessage)

    it "saves a Chat" do
      chat = Generator.chat.save!

      chat.should_not be_nil
      chat.persisted?.should be_true
      Chat.find!(chat.id).id.should eq chat.id
    end

    it "save Chat Messages" do
      chat = Generator.chat.save!
      msg1 = Generator.chat_message(chat).save!

      msg1.should_not be_nil
      msg1.persisted?.should be_true
      ChatMessage.find!(msg1.id).id.should eq msg1.id

      chat.messages.size.should eq(1)

      Generator.chat_message(chat).save!
      chat.messages.size.should eq(2)
    end
  end
end
