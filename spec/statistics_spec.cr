require "./helper"

module PlaceOS::Model
  describe Statistics do
    it "saves some statistics" do
      stats = Statistics.new
      stats.modules_disconnected = 2

      begin
        stats.save!
      rescue e : PgORM::Error::RecordInvalid
        inspect_error(e)
        raise e
      end

      stats.should_not be_nil
      id = stats.id
      id.should start_with "stats-" if id

      stats.ttl.should be < 31.days.from_now.to_unix
      stats.ttl.should be > 29.days.from_now.to_unix

      stats.persisted?.should be_true
      stats.destroy
    end
  end
end
