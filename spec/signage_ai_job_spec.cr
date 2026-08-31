require "./helper"
require "uuid"

module PlaceOS::Model
  # created_at is written by the Timestamps module on insert, so a row can only
  # be aged by moving it afterwards.
  def self.backdate_job(job : SignageAIJob, age : Time::Span)
    ::PgORM::Database.connection do |db|
      db.exec("UPDATE signage_ai_jobs SET created_at = $1 WHERE id = $2", Time.utc - age, job.id.as(UUID))
    end
  end

  describe SignageAIJob do
    Spec.before_each do
      SignageAIJob.clear
      SignageAIProvider.clear
    end

    test_round_trip(SignageAIJob)

    it "writes candidates concurrently without losing entries" do
      job = Generator.signage_ai_job(candidates: 4).save!
      id = job.id.as(UUID)

      done = Channel(Nil).new
      4.times do |index|
        spawn do
          SignageAIJob.bump_image(id, index, {"state" => JSON::Any.new("done"), "upload_id" => JSON::Any.new("uploads-#{index}")})
          done.send(nil)
        end
      end
      4.times { done.receive }

      found = SignageAIJob.find!(id)
      found.images.size.should eq 4
      found.images.each_with_index do |image, index|
        image["upload_id"].as_s.should eq "uploads-#{index}"
      end
      found.images_produced.should eq 4
      found.version.should eq 4
    end

    it "builds the images array when result has no images key" do
      job = Generator.signage_ai_job(candidates: 1).save!
      job.result = JSON::Any.new({} of String => JSON::Any)
      job.save!

      SignageAIJob.bump_image(job.id.as(UUID), 0, {"state" => JSON::Any.new("done")})
      SignageAIJob.find!(job.id.as(UUID)).images.size.should eq 1
    end

    it "bumps the version on its own" do
      job = Generator.signage_ai_job.save!
      SignageAIJob.bump_version(job.id.as(UUID)).should eq 1
      SignageAIJob.find!(job.id.as(UUID)).version.should eq 1
    end

    it "sums candidates for quotas, counting failed jobs too" do
      authority = Generator.localhost_authority
      user = Generator.user(authority: authority).save!
      Generator.signage_ai_job(authority: authority, user: user, candidates: 3).save!
      Generator.signage_ai_job(authority: authority, user: user, candidates: 2, state: SignageAIJob::State::Done).save!
      Generator.signage_ai_job(authority: authority, user: user, candidates: 9, state: SignageAIJob::State::Failed).save!

      # a failed job usually still reached the vendor and was billed
      since = 1.day.ago
      SignageAIJob.sum_candidates(user.id.as(String), since).should eq 14
      SignageAIJob.sum_candidates_for_authority(authority.id.as(String), since).should eq 14
      SignageAIJob.sum_candidates(user.id.as(String), 1.minute.from_now).should eq 0
    end

    it "walks a refine chain oldest first" do
      first = Generator.signage_ai_job.save!
      second = Generator.signage_ai_job(parent_job_id: first.id.as(UUID)).save!
      third = Generator.signage_ai_job(parent_job_id: second.id.as(UUID)).save!

      third.chain.map(&.id).should eq [first.id, second.id]
      first.chain.should be_empty
    end

    it "reports final states" do
      SignageAIJob::State::Queued.final?.should be_false
      SignageAIJob::State::Running.final?.should be_false
      SignageAIJob::State::Done.final?.should be_true
      SignageAIJob::State::Failed.final?.should be_true
      SignageAIJob::State::Cancelled.final?.should be_true
    end

    it "finds jobs left running by a replica that went away" do
      job = Generator.signage_ai_job(state: SignageAIJob::State::Running).save!
      job.started_at = 30.minutes.ago
      job.save!

      SignageAIJob.stale(10.minutes.ago).map(&.id).should eq [job.id]
      SignageAIJob.stale(1.hour.ago).should be_empty
    end

    it "groups usage by provider and model" do
      authority = Generator.localhost_authority
      provider = Generator.signage_ai_provider(authority: authority).save!
      2.times do
        job = Generator.signage_ai_job(authority: authority, provider: provider, candidates: 2).save!
        job.images_produced = 2
        job.cost_units = 0.5
        job.save!
      end

      rows = SignageAIJob.usage(authority.id.as(String), 1.day.ago, 1.day.from_now)
      rows.size.should eq 1
      row = rows.first
      row.provider.should eq "OPENAI"
      row.model.should eq "gpt-image-2"
      row.jobs.should eq 2
      row.candidates.should eq 4
      row.images_produced.should eq 4
      row.cost_units.should eq 1.0
    end

    describe "automatic cleanup" do
      # cleanup ships off, so every example that exercises it has to turn it on
      before_each { SignageAIJob.cleanup_after = 90.days }
      after_each { SignageAIJob.cleanup_after = SignageAIJob::CLEANUP_AFTER }

      it "does nothing unless an operator configures a window" do
        SignageAIJob::CLEANUP_AFTER.should eq Time::Span.zero

        SignageAIJob.cleanup_after = SignageAIJob::CLEANUP_AFTER
        job = Generator.signage_ai_job.save!
        PlaceOS::Model.backdate_job(job, 1825.days)

        Generator.signage_ai_job.save!

        SignageAIJob.find?(job.id.as(UUID)).should_not be_nil
      end

      it "removes jobs past the window as a new job is created" do
        old_job = Generator.signage_ai_job.save!
        recent = Generator.signage_ai_job.save!
        PlaceOS::Model.backdate_job(old_job, 100.days)

        # nothing has run yet: the row is old but no insert has happened since
        SignageAIJob.find?(old_job.id.as(UUID)).should_not be_nil

        # the insert itself is what triggers the sweep
        fresh = Generator.signage_ai_job.save!

        SignageAIJob.find?(old_job.id.as(UUID)).should be_nil
        SignageAIJob.find?(recent.id.as(UUID)).should_not be_nil
        SignageAIJob.find?(fresh.id.as(UUID)).should_not be_nil
      end

      it "keeps jobs inside the window" do
        job = Generator.signage_ai_job.save!
        PlaceOS::Model.backdate_job(job, 89.days)

        Generator.signage_ai_job.save!

        SignageAIJob.find?(job.id.as(UUID)).should_not be_nil
      end

      it "keeps everything when the window is explicitly zero" do
        SignageAIJob.cleanup_after = Time::Span.zero
        job = Generator.signage_ai_job.save!
        PlaceOS::Model.backdate_job(job, 1825.days)

        Generator.signage_ai_job.save!

        SignageAIJob.find?(job.id.as(UUID)).should_not be_nil
        SignageAIJob.cleanup_expired.should eq 0
      end

      it "reads a negative window as keep everything, not delete everything" do
        SignageAIJob.cleanup_after = -30.days
        job = Generator.signage_ai_job.save!
        PlaceOS::Model.backdate_job(job, 1825.days)

        SignageAIJob.cleanup_expired.should eq 0
        SignageAIJob.find?(job.id.as(UUID)).should_not be_nil
      end

      it "bounds how much one insert removes" do
        # create them all first: each insert sweeps, so backdating as we go would
        # let the second insert remove the first row before the third exists
        jobs = Array.new(3) { Generator.signage_ai_job.save! }
        jobs.each { |job| PlaceOS::Model.backdate_job(job, 100.days) }

        SignageAIJob.count.should eq 3
        {SignageAIJob.cleanup_expired(limit: 2), SignageAIJob.count}.should eq({2, 1})
        {SignageAIJob.cleanup_expired(limit: 2), SignageAIJob.count}.should eq({1, 0})
        SignageAIJob.cleanup_expired(limit: 2).should eq 0
      end

      it "removes the oldest first" do
        oldest = Generator.signage_ai_job.save!
        newest = Generator.signage_ai_job.save!
        PlaceOS::Model.backdate_job(oldest, 200.days)
        PlaceOS::Model.backdate_job(newest, 100.days)

        SignageAIJob.count.should eq 2
        {SignageAIJob.cleanup_expired(limit: 1), SignageAIJob.count}.should eq({1, 1})
        SignageAIJob.find?(oldest.id.as(UUID)).should be_nil
        SignageAIJob.find?(newest.id.as(UUID)).should_not be_nil
      end

      it "keeps a recent refine when its parent ages out" do
        parent = Generator.signage_ai_job.save!
        child = Generator.signage_ai_job(parent_job_id: parent.id.as(UUID)).save!
        PlaceOS::Model.backdate_job(parent, 100.days)

        SignageAIJob.cleanup_expired.should eq 1

        found = SignageAIJob.find?(child.id.as(UUID))
        found.should_not be_nil
        found.as(SignageAIJob).parent_job_id.should be_nil
      end
    end

    it "clears the provider link but keeps the job when a provider is deleted" do
      authority = Generator.localhost_authority
      provider = Generator.signage_ai_provider(authority: authority).save!
      job = Generator.signage_ai_job(authority: authority, provider: provider).save!

      provider.destroy

      found = SignageAIJob.find!(job.id.as(UUID))
      found.provider_id.should be_nil
      found.provider_type.should eq "OPENAI"
      found.model.should eq "gpt-image-2"
    end
  end
end
