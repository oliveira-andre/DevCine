require "rails_helper"

# The videos:* backfill tasks (lib/tasks/video_ingest.rake). The services they
# drive have their own specs; these cover the tasks' own logic — what they
# skip, which service they call, and the summary they print.
RSpec.describe "videos rake tasks", type: :task do
  def ingest_result(status, error: nil)
    VideoIngest::Result.new(status: status, audio_tracks: 2, subtitles: 1, error: error)
  end

  before { allow(VideoFrameExtractor).to receive(:available?).and_return(true) }

  shared_examples "an ffmpeg-gated task" do |name|
    it "aborts when ffmpeg is unavailable" do
      allow(VideoFrameExtractor).to receive(:available?).and_return(false)
      expect { run_rake(name) }.to raise_error(SystemExit)
    end
  end

  describe "videos:ingest" do
    it_behaves_like "an ffmpeg-gated task", "videos:ingest"

    it "ingests only file-backed, not-yet-ingested, non-live videos and reports each outcome" do
      mkv = create(:video, :with_file, title: "Dual Audio")
      plain = create(:video, :with_file, title: "Plain")
      broken = create(:video, :with_file, title: "Broken")
      already = create(:video, :with_file)
      already.audio_tracks.create!(name: "default", position: 1)
      no_file = create(:video)
      live = create(:video, :live)

      allow(VideoIngest).to receive(:call) do |video|
        { mkv.id => ingest_result(:remuxed), plain.id => ingest_result(:default),
          broken.id => ingest_result(:failed, error: "ffprobe exploded") }.fetch(video.id)
      end

      out, err = run_rake("videos:ingest")

      expect(VideoIngest).to have_received(:call).exactly(3).times
      expect(VideoIngest).not_to have_received(:call).with(already)
      expect(VideoIngest).not_to have_received(:call).with(no_file)
      expect(VideoIngest).not_to have_received(:call).with(live)
      expect(out).to include("MKV: 2 audio track(s), 1 subtitle(s)")
      expect(out).to include("remuxed=1 defaulted=1 skipped=2 failed=1 of 5.")
      expect(err).to include("ffprobe exploded")
    end
  end

  describe "videos:reencode" do
    it_behaves_like "an ffmpeg-gated task", "videos:reencode"

    it "re-encodes only what VideoIngest flags unsafe and keeps going past a failure" do
      hevc = create(:video, :with_file)
      safe = create(:video, :with_file)
      broken = create(:video, :with_file)
      create(:video) # no file → skipped

      allow(VideoIngest).to receive(:reencode) do |video|
        { hevc.id => ingest_result(:transcoded), safe.id => ingest_result(:safe),
          broken.id => ingest_result(:failed, error: "libx264 missing") }.fetch(video.id)
      end

      out, err = run_rake("videos:reencode")

      expect(VideoIngest).to have_received(:reencode).exactly(3).times
      expect(out).to include("re-encoded to H.264")
      expect(out).to include("transcoded=1 already_safe=1 skipped=1 failed=1 of 4.")
      expect(err).to include("libx264 missing")
    end
  end

  describe "videos:hls" do
    it_behaves_like "an ffmpeg-gated task", "videos:hls"

    it "packages only ingested, file-backed videos without a package" do
      ready = create(:video, :with_file)
      ready.audio_tracks.create!(name: "default", position: 1)
      failing = create(:video, :with_file)
      failing.audio_tracks.create!(name: "default", position: 1)
      packaged = create(:video, :with_file, hls_ready_at: Time.current)
      packaged.audio_tracks.create!(name: "default", position: 1)
      create(:video, :with_file) # not ingested yet (no audio tracks)
      create(:video)             # no file

      allow(HlsPackager).to receive(:call) do |video|
        if video.id == ready.id
          HlsPackager::Result.new(status: :packaged, renditions: 1, error: nil)
        else
          HlsPackager::Result.new(status: :failed, renditions: 0, error: "segmenting failed")
        end
      end

      out, err = run_rake("videos:hls")

      expect(HlsPackager).to have_received(:call).twice
      expect(HlsPackager).not_to have_received(:call).with(packaged)
      expect(out).to include("packaged=1 skipped=3 failed=1 of 5.")
      expect(err).to include("segmenting failed")
    end
  end

  describe "videos:clean_subtitles" do
    def subtitle_with(srt, filename: "eng.srt")
      create(:subtitle, video: create(:video)).tap do |subtitle|
        subtitle.file.attach(io: StringIO.new(srt), filename: filename, content_type: "application/x-subrip")
      end
    end

    it "strips styling junk from stored files, keeping the timing and the filename" do
      dirty = subtitle_with(<<~SRT, filename: "styled.srt")
        1
        00:00:46,440 --> 00:00:48,540
        <font face="RH Sans" size="78">{\\an8}My head hurts.</font>
      SRT

      out, _err = run_rake("videos:clean_subtitles")

      dirty.reload
      expect(dirty.file.download).to eq("1\n00:00:46,440 --> 00:00:48,540\nMy head hurts.\n")
      expect(dirty.file.filename.to_s).to eq("styled.srt")
      expect(out).to include("cleaned=1 already_clean=0 failed=0 of 1.")
    end

    it "leaves already-clean files untouched (no new blob)" do
      clean = subtitle_with("1\n00:00:01,000 --> 00:00:02,000\nHello\n")
      blob_id = clean.file.blob.id

      out, _err = run_rake("videos:clean_subtitles")

      expect(clean.reload.file.blob.id).to eq(blob_id)
      expect(out).to include("cleaned=0 already_clean=1 failed=0 of 1.")
    end

    it "keeps a file that would be emptied by sanitizing, and reports it" do
      only_styling = subtitle_with("1\n00:00:01,000 --> 00:00:02,000\n<b>{\\an8}</b>\n")
      blob_id = only_styling.file.blob.id

      out, err = run_rake("videos:clean_subtitles")

      expect(only_styling.reload.file.blob.id).to eq(blob_id)
      expect(err).to include("nothing left after sanitizing, file kept")
      expect(out).to include("cleaned=0 already_clean=0 failed=1 of 1.")
    end
  end
end
