require "./helper"
require "uuid"

module PlaceOS::Model
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
