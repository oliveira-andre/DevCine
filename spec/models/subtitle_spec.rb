require 'rails_helper'

RSpec.describe Subtitle, type: :model do
  it "has a valid factory (with a file)" do
    expect(build(:subtitle, :with_file)).to be_valid
  end

  it { is_expected.to belong_to(:video) }

  it "has a file attachment" do
    expect(described_class.reflect_on_attachment(:file)).to be_present
  end

  describe "language enum" do
    it { is_expected.to respond_to(:english?) }

    it "titleizes the label" do
      expect(build(:subtitle, language: :portuguese).label).to eq("Portuguese")
    end
  end

  describe "validations" do
    it "requires an attached .srt file" do
      expect(build(:subtitle)).to be_invalid # no file
      expect(build(:subtitle, :with_file)).to be_valid
    end

    it "rejects a non-.srt file" do
      s = build(:subtitle)
      s.file.attach(io: StringIO.new("x"), filename: "captions.vtt", content_type: "text/vtt")
      expect(s).to be_invalid
    end
  end

  describe "single default per video (FR-013)" do
    it "unsets other defaults when one is set" do
      video = create(:video, :with_file)
      a = create(:subtitle, :with_file, video: video, language: :english, is_default: true)
      b = create(:subtitle, :with_file, video: video, language: :spanish, is_default: true)
      expect(a.reload.is_default).to be(false)
      expect(b.reload.is_default).to be(true)
    end
  end

  describe "#to_vtt" do
    it "produces a WEBVTT header and converts comma timestamps to dots" do
      vtt = create(:subtitle, :with_file).to_vtt
      expect(vtt).to start_with("WEBVTT\n\n")
      expect(vtt).to include("00:00:01.000 --> 00:00:04.000")
      expect(vtt).not_to include("00:00:01,000")
    end

    it "handles non-ASCII (UTF-8) captions" do
      s = build(:subtitle)
      s.file.attach(io: StringIO.new("1\n00:00:01,000 --> 00:00:02,000\nDisfruta la función\n"),
                    filename: "es.srt", content_type: "application/x-subrip")
      s.save!
      expect(s.to_vtt).to include("Disfruta la función")
    end
  end
end
