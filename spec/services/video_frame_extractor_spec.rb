require 'rails_helper'

RSpec.describe VideoFrameExtractor do
  let(:video) { build(:video) }

  def attach_video_file(record, path: Rails.root.join("spec/fixtures/files/sample_video.mp4"))
    record.file.attach(io: File.open(path), filename: File.basename(path), content_type: "video/mp4")
    record.save!
    record
  end

  describe ".available?" do
    before { described_class.reset_availability! }
    after { described_class.reset_availability! }

    it "is false when ffmpeg is not installed at all" do
      allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)

      expect(described_class).not_to be_available
    end

    # A broken Homebrew ffmpeg (missing shared library) exits non-zero on
    # -version rather than being absent, so presence alone is not enough.
    it "is false when the binary is present but fails to run" do
      allow(Open3).to receive(:capture3)
        .and_return([ "", "dyld: Library not loaded", instance_double(Process::Status, success?: false) ])

      expect(described_class).not_to be_available
    end
  end

  describe "#call" do
    it "returns nothing when no file is attached" do
      result = described_class.call(create(:video))

      expect(result).not_to be_any
      expect(result.error).to match(/no video file/)
    end

    it "returns nothing, without raising, when ffmpeg is unavailable" do
      allow(described_class).to receive(:available?).and_return(false)

      result = described_class.call(attach_video_file(create(:video)))

      expect(result).not_to be_any
      expect(result.error).to match(/unavailable/)
    end

    # An upload must never fail because the thumbnail nicety blew up.
    it "swallows an unexpected error and reports it as a failure" do
      video = attach_video_file(create(:video))
      # Raise at the ffmpeg boundary rather than inside ActiveStorage: `open`
      # reaches Blob through two delegate_missing_to hops, so stubbing it would
      # pin this spec to Rails internals.
      allow(Open3).to receive(:popen3).and_raise(StandardError, "boom")

      expect { @result = described_class.call(video) }.not_to raise_error
      expect(@result).not_to be_any
      expect(@result.error).to be_present
    end

    context "with ffmpeg available", :ffmpeg do
      let(:video) { attach_video_file(create(:video)) }

      it "extracts the requested number of JPEG frames" do
        result = described_class.call(video)

        expect(result.error).to be_nil
        expect(result.frames.size).to eq(described_class::FRAME_COUNT)
        result.frames.each do |frame|
          expect(File.size(frame.path)).to be > 0
          # JPEG magic number.
          expect(File.binread(frame.path, 2).unpack1("H*")).to eq("ffd8")
        end
      ensure
        result&.frames&.each { |f| f.close! }
      end

      it "samples distinct moments rather than the same frame three times" do
        result = described_class.call(video)

        digests = result.frames.map { |f| Digest::SHA256.file(f.path).hexdigest }
        expect(digests.uniq.size).to eq(digests.size)
      ensure
        result&.frames&.each { |f| f.close! }
      end

      # The first and last moments are usually black or a fade — useless.
      it "samples away from both ends of the video" do
        duration = 4.0
        stamps = described_class.new(video).send(:timestamps, duration)

        expect(stamps.size).to eq(described_class::FRAME_COUNT)
        expect(stamps.min).to be >= duration * described_class::USABLE_RANGE.begin
        expect(stamps.max).to be <= duration * described_class::USABLE_RANGE.end
      end

      it "spreads the samples so two never land on the same moment" do
        stamps = described_class.new(video).send(:timestamps, 60.0)

        expect(stamps).to eq(stamps.sort)
        expect(stamps.uniq.size).to eq(stamps.size)
      end

      it "honours explicit timestamps" do
        result = described_class.call(video, at: [ 1.0 ])

        expect(result.frames.size).to eq(1)
      ensure
        result&.frames&.each { |f| f.close! }
      end
    end
  end
end
