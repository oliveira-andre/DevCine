require 'rails_helper'

# Each check is driven through `call`, so a failing service must come back as
# `false`, never as an exception. Failures are made in the service a check
# talks to, not by stubbing the check: RSpec would leave the original behind as
# a public method, which `call` would then report as an extra check.
RSpec.describe HealthCheckService do
  subject(:result) { described_class.new.call }

  let(:storage_root) { Dir.mktmpdir("health_check_storage") }
  # Test env uses :null_store; use a real in-memory store to observe caching.
  let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }

  # Every service healthy; examples break one at a time.
  before do
    allow(HTTParty).to receive(:get).and_return(double(success?: true))
    allow(Rails).to receive(:cache).and_return(cache_store)
    allow(VideoFrameExtractor).to receive(:available?).and_return(true)
    allow(ActiveStorage::Blob.service).to receive(:root).and_return(storage_root)
  end

  after do
    FileUtils.chmod(0o755, storage_root) if File.directory?(storage_root)
    FileUtils.remove_entry(storage_root) if File.exist?(storage_root)
  end

  it "reports app first, then every check by name, all on" do
    expect(result.keys).to eq(%i[app cache database ffmpeg storage])
    expect(result.values).to all(be(true))
  end

  describe "app" do
    it "requests the project's own /up" do
      result
      expect(HTTParty).to have_received(:get).with("http://localhost:3000/up", timeout: 5)
    end

    it "is off when /up answers with an error" do
      allow(HTTParty).to receive(:get).and_return(double(success?: false))
      expect(result).to include(app: false)
    end

    it "is off when /up doesn't answer in time" do
      allow(HTTParty).to receive(:get).and_raise(Net::OpenTimeout)
      expect(result).to include(app: false)
    end
  end

  describe "cache" do
    it "is off when the cache keeps nothing" do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::NullStore.new)
      expect(result).to include(cache: false)
    end

    it "leaves no entry behind" do
      allow(cache_store).to receive(:delete).and_call_original
      result
      expect(cache_store).to have_received(:delete) { |key| expect(cache_store.read(key)).to be_nil }
    end
  end

  describe "database" do
    it "is off when the database can't be reached" do
      allow(ActiveRecord::Base).to receive(:with_connection).and_raise(ActiveRecord::ConnectionNotEstablished)
      expect(result).to include(database: false)
    end
  end

  describe "ffmpeg" do
    it "is off when ffmpeg can't run" do
      allow(VideoFrameExtractor).to receive(:available?).and_return(false)
      expect(result).to include(ffmpeg: false)
    end
  end

  describe "queue" do
    it "is left out where Active Job doesn't run on Solid Queue" do
      expect(result).not_to have_key(:queue)
    end

    context "when Active Job runs on Solid Queue" do
      # The Solid Queue tables live in the production queue database, not the
      # test one, so the process model is stood in for.
      let(:processes) { double("SolidQueue::Process") }

      before do
        allow(ActiveJob::Base).to receive(:queue_adapter_name).and_return("solid_queue")
        stub_const("SolidQueue::Process", processes)
      end

      it "is on when a process has checked in recently, in name order" do
        allow(processes).to receive(:where).and_return(double(exists?: true))

        expect(result.keys).to eq(%i[app cache database ffmpeg queue storage])
        expect(result).to include(queue: true)
        # "Recently" is Solid Queue's own liveness window (5 minutes).
        expect(processes).to have_received(:where) do |conditions|
          expect(conditions[:last_heartbeat_at].begin).to be_within(1.second).of(5.minutes.ago)
        end
      end

      it "is off when no process has checked in recently" do
        allow(processes).to receive(:where).and_return(double(exists?: false))
        expect(result).to include(queue: false)
      end

      it "is off when the queue database can't be reached" do
        allow(processes).to receive(:where).and_raise(ActiveRecord::ConnectionNotEstablished)
        expect(result).to include(queue: false)
      end
    end
  end

  describe "storage" do
    it "is off when the storage folder is missing" do
      FileUtils.remove_entry(storage_root)
      expect(result).to include(storage: false)
    end

    it "is off when the storage folder is read-only" do
      FileUtils.chmod(0o555, storage_root)
      expect(result).to include(storage: false)
    end
  end
end
