require "rails_helper"

RSpec.describe HlsPackager, :ffmpeg do
  let(:video) { create(:video) }

  # A short H.264+AAC MP4 (what VideoIngest produces) + a stripped .m4a track.
  def attach_ingested_video(dir)
    mp4 = File.join(dir, "main.mp4")
    system("ffmpeg", "-y", "-v", "error",
           "-f", "lavfi", "-i", "testsrc=duration=4:size=320x180:rate=10",
           "-f", "lavfi", "-i", "sine=frequency=440:duration=4",
           "-c:v", "libx264", "-preset", "ultrafast", "-c:a", "aac", mp4, exception: true)
    video.file.attach(io: File.open(mp4, "rb"), filename: "main.mp4", content_type: "video/mp4")

    m4a = File.join(dir, "english.m4a")
    system("ffmpeg", "-y", "-v", "error",
           "-f", "lavfi", "-i", "sine=frequency=880:duration=4",
           "-c:a", "aac", m4a, exception: true)
    video.audio_tracks.create!(name: "Português", language: "por", position: 1)
    video.audio_tracks.create!(name: "English", language: "eng", position: 2).tap do |track|
      track.file.attach(io: File.open(m4a, "rb"), filename: "english.m4a", content_type: "audio/mp4")
    end
  end

  after { FileUtils.rm_rf(described_class.dir_for(video)) }

  it "packages video + one audio rendition per track and writes the master by hand" do
    Dir.mktmpdir do |dir|
      attach_ingested_video(dir)
      result = described_class.call(video)

      expect(result.error).to be_nil
      expect(result.renditions).to eq(2)
      expect(video.reload).to be_hls_ready

      base = described_class.dir_for(video)
      master = base.join("master.m3u8").read
      expect(master).to include('NAME="Português"', "DEFAULT=YES", 'LANGUAGE="por"', 'URI="audio-0/index.m3u8"')
      expect(master).to include('NAME="English"', 'URI="audio-1/index.m3u8"')
      expect(master).to match(/#EXT-X-STREAM-INF:BANDWIDTH=\d+,AUDIO="aud"/)

      expect(base.join("video/index.m3u8")).to be_file
      expect(base.join("video/init.mp4")).to be_file
      expect(base.join("audio-0/index.m3u8")).to be_file
      expect(base.join("audio-1/index.m3u8")).to be_file
      expect(Dir.glob(base.join("video/seg_*.m4s"))).not_to be_empty
    end
  end

  it "refuses to package before the ingest created audio tracks" do
    Dir.mktmpdir do |dir|
      mp4 = File.join(dir, "m.mp4")
      system("ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", "testsrc=duration=1:size=160x90:rate=10",
             "-c:v", "libx264", "-preset", "ultrafast", mp4, exception: true)
      video.file.attach(io: File.open(mp4, "rb"), filename: "m.mp4", content_type: "video/mp4")

      result = described_class.call(video)
      expect(result.status).to eq(:failed)
      expect(result.error).to include("no audio tracks")
      expect(video.reload).not_to be_hls_ready
    end
  end

  it ".discard wipes the package and flips playback back to progressive" do
    Dir.mktmpdir do |dir|
      attach_ingested_video(dir)
      described_class.call(video)

      described_class.discard(video.reload)

      expect(video.reload).not_to be_hls_ready
      expect(described_class.dir_for(video)).not_to be_directory
    end
  end
end
