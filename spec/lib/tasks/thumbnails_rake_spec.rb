require "rails_helper"

# thumbnails:backfill (lib/tasks/thumbnails.rake): what it skips and how it
# reports. Frame extraction itself is covered by the Video/extractor specs.
RSpec.describe "thumbnails:backfill", type: :task do
  before { allow(VideoFrameExtractor).to receive(:available?).and_return(true) }

  it "aborts when ffmpeg is unavailable" do
    allow(VideoFrameExtractor).to receive(:available?).and_return(false)
    expect { run_rake("thumbnails:backfill") }.to raise_error(SystemExit)
  end

  it "fills only file-backed videos without a thumbnail and survives a failing one" do
    good = create(:video, :with_file, title: "Good")
    no_frame = create(:video, :with_file, title: "No Frame")
    raising = create(:video, :with_file, title: "Raising")
    create(:video, :with_file, :with_thumbnail) # already has one
    create(:video)                               # no file
    create(:video, :live)                        # lives aren't scanned

    outcomes = { good.id => true, no_frame.id => false }
    allow_any_instance_of(Video).to receive(:attach_generated_thumbnail!) do |video|
      raise "decoder crashed" if video.id == raising.id

      outcomes.fetch(video.id)
    end

    out, err = run_rake("thumbnails:backfill")

    expect(out).to include("✓ #{good.slug}")
    expect(err).to include("✗ #{no_frame.slug} — no frame could be extracted")
    expect(err).to include("✗ #{raising.slug} — RuntimeError: decoder crashed")
    expect(out).to include("attached=1 skipped=2 (already had one or no file) failed=2 of 5.")
  end
end
