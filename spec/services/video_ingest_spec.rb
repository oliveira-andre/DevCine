require "rails_helper"

RSpec.describe VideoIngest do
  let(:video) { create(:video) }

  def attach(path, content_type)
    video.file.attach(io: File.open(path, "rb"), filename: File.basename(path), content_type: content_type)
  end

  def probe_video_stream(video)
    video.file.open do |f|
      JSON.parse(`ffprobe -v error -print_format json -show_streams #{f.path.shellescape}`)["streams"]
        .find { |s| s["codec_type"] == "video" }
    end
  end

  # HEVC Main 10 — decodes on macOS, nowhere reliable elsewhere (the Kobayashi
  # case). 1 second of testsrc keeps the transcode fast.
  def build_hevc_mp4(dir)
    out = File.join(dir, "hevc10.mp4")
    system(
      "ffmpeg", "-y", "-v", "error",
      "-f", "lavfi", "-i", "testsrc=duration=1:size=320x180:rate=10",
      "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
      "-c:v", "libx265", "-preset", "ultrafast", "-pix_fmt", "yuv420p10le",
      "-tag:v", "hvc1", "-c:a", "aac", out, exception: true
    )
    out
  end

  # A genuine two-audio + one-subtitle MKV, built by the real ffmpeg.
  def build_mkv(dir, video_codec: [ "-c:v", "libx264", "-preset", "ultrafast" ])
    srt = File.join(dir, "probe.srt")
    File.write(srt, "1\n00:00:00,100 --> 00:00:00,900\nOla mundo\n")
    out = File.join(dir, "probe.mkv")
    system(
      "ffmpeg", "-y", "-v", "error",
      "-f", "lavfi", "-i", "testsrc=duration=1:size=320x180:rate=10",
      "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
      "-f", "lavfi", "-i", "sine=frequency=880:duration=1",
      "-i", srt,
      "-map", "0:v", "-map", "1:a", "-map", "2:a", "-map", "3:s",
      *video_codec, "-c:a", "aac", "-c:s", "srt",
      "-metadata:s:a:0", "title=Português", "-metadata:s:a:0", "language=por",
      "-metadata:s:a:1", "title=English", "-metadata:s:a:1", "language=eng",
      "-metadata:s:s:0", "language=por", "-metadata:s:s:0", "title=Legenda PT",
      out, exception: true
    )
    out
  end

  describe "an MKV upload", :ffmpeg do
    it "remuxes to MP4 and strips the named audio + subtitle tracks" do
      Dir.mktmpdir do |dir|
        attach(build_mkv(dir), "video/x-matroska")
        result = described_class.call(video)

        expect(result.error).to be_nil
        expect(result.status).to eq(:remuxed)

        # The playable file is now a faststart MP4 (video stream untouched).
        video.reload
        expect(video.file.filename.to_s).to eq("probe.mp4")
        expect(video.file.content_type).to eq("video/mp4")
        video.file.open do |f|
          format = JSON.parse(`ffprobe -v error -print_format json -show_format #{f.path.shellescape}`)
          expect(format.dig("format", "format_name")).to include("mp4")
        end

        # Audio tracks named from the container, first = default (no file —
        # its sound is inside the MP4), alternates stripped to .m4a.
        tracks = video.audio_tracks.ordered
        expect(tracks.map(&:name)).to eq([ "Português", "English" ])
        expect(tracks.map(&:language)).to eq([ "por", "eng" ])
        expect(tracks.first).to be_default
        expect(tracks.first.file).not_to be_attached
        expect(tracks.last.file).to be_attached
        expect(tracks.last.file.filename.to_s).to end_with(".m4a")

        # The embedded subtitle landed in the existing Subtitle system.
        subtitle = video.subtitles.sole
        expect(subtitle.language).to eq("portuguese")
        expect(subtitle.file.filename.to_s).to end_with(".srt")
        expect(subtitle.file.download).to include("Ola mundo")
      end
    end

    it "is idempotent — a second run skips" do
      Dir.mktmpdir do |dir|
        attach(build_mkv(dir), "video/x-matroska")
        described_class.call(video)

        expect { expect(described_class.call(video).status).to eq(:skipped) }
          .not_to change { [ video.audio_tracks.count, video.subtitles.count ] }
      end
    end
  end

  describe "a non-MKV upload", :ffmpeg do
    it "keeps the file untouched and names a single 'default' track" do
      attach(Rails.root.join("spec/fixtures/files/sample_video.mp4"), "video/mp4")
      blob_before = video.file.blob.id

      result = described_class.call(video)

      expect(result.status).to eq(:default)
      expect(video.reload.file.blob.id).to eq(blob_before) # untouched
      track = video.audio_tracks.sole
      expect(track.name).to eq("default")
      expect(track).to be_default
      expect(track.file).not_to be_attached
    end
  end

  it "reports (not raises) when there is no file" do
    result = described_class.call(video)
    expect(result.status).to eq(:failed)
    expect(result.error).to include("no video file")
  end

  describe "browser-unsafe codecs (HEVC / 10-bit)", :ffmpeg do
    it "re-encodes an HEVC 10-bit MP4 to H.264 8-bit at ingest" do
      Dir.mktmpdir do |dir|
        attach(build_hevc_mp4(dir), "video/mp4")
        result = described_class.call(video)

        expect(result.status).to eq(:transcoded)
        stream = probe_video_stream(video.reload)
        expect(stream["codec_name"]).to eq("h264")
        expect(stream["pix_fmt"]).to eq("yuv420p")
        expect(video.audio_tracks.sole.name).to eq("default")
      end
    end

    it "transcodes the video while stripping an HEVC MKV's tracks" do
      Dir.mktmpdir do |dir|
        attach(build_mkv(dir, video_codec: [ "-c:v", "libx265", "-preset", "ultrafast", "-pix_fmt", "yuv420p10le" ]),
               "video/x-matroska")
        result = described_class.call(video)

        expect(result.status).to eq(:remuxed)
        expect(probe_video_stream(video.reload)["codec_name"]).to eq("h264")
        expect(video.audio_tracks.ordered.map(&:name)).to eq([ "Português", "English" ])
      end
    end

    it "#reencode fixes an already-stored unsafe file, leaving tracks alone" do
      Dir.mktmpdir do |dir|
        attach(build_hevc_mp4(dir), "video/mp4")
        video.audio_tracks.create!(name: "default", position: 1) # already ingested

        result = described_class.reencode(video)

        expect(result.status).to eq(:transcoded)
        expect(probe_video_stream(video.reload)["codec_name"]).to eq("h264")
        expect(video.audio_tracks.count).to eq(1) # untouched
      end
    end

    it "#reencode is a no-op for a decodable file" do
      attach(Rails.root.join("spec/fixtures/files/sample_video.mp4"), "video/mp4")
      blob_before = video.file.blob.id

      expect(described_class.reencode(video).status).to eq(:safe)
      expect(video.reload.file.blob.id).to eq(blob_before)
    end
  end
end
