require "rails_helper"

RSpec.describe ChunkedUpload do
  let(:user) { create(:user) }
  let(:id) { "11111111-2222-4333-8444-555555555555" }

  # Keep the scratch tree out of the real tmp dir and swept between examples.
  around do |example|
    example.run
  ensure
    FileUtils.rm_rf(ChunkedUpload.dir_for(user))
  end

  it "rejects an id that isn't a UUID (no path traversal)" do
    expect { described_class.new(user, "../../etc/passwd") }.to raise_error(ChunkedUpload::InvalidId)
    expect { described_class.new(user, "") }.to raise_error(ChunkedUpload::InvalidId)
  end

  it "assembles chunks in order into one file" do
    upload = described_class.new(user, id)
    upload.append(StringIO.new("hello "), first: true)
    upload.append(StringIO.new("chunked "), first: false)
    upload.append(StringIO.new("world"), first: false)

    expect(File.read(upload.path)).to eq("hello chunked world")
  end

  it "truncates when the first chunk is re-sent (a reused id starts clean)" do
    upload = described_class.new(user, id)
    upload.append(StringIO.new("stale-bytes"), first: true)
    upload.append(StringIO.new("fresh"), first: true)

    expect(File.read(upload.path)).to eq("fresh")
  end

  it "scopes the scratch file under the owning user" do
    other = create(:user)
    expect(described_class.new(user, id).path.to_s).to include(user.id.to_s)
    expect(described_class.new(other, id).path.to_s).to include(other.id.to_s)
    expect(described_class.new(user, id).path).not_to eq(described_class.new(other, id).path)
  end

  describe "#to_attachable" do
    it "presents the assembled bytes as an Active Storage attachable hash" do
      upload = described_class.new(user, id)
      upload.append(StringIO.new("movie-bytes"), first: true)

      attachable = upload.to_attachable(filename: "movie.mp4", content_type: "video/mp4")
      expect(attachable[:filename]).to eq("movie.mp4")
      expect(attachable[:content_type]).to eq("video/mp4")
      expect(attachable[:io].read).to eq("movie-bytes")
    end

    it "falls back to safe defaults for a missing filename / content type" do
      upload = described_class.new(user, id)
      upload.append(StringIO.new("bytes"), first: true)

      attachable = upload.to_attachable(filename: nil, content_type: "")
      expect(attachable[:filename]).to eq("upload")
      expect(attachable[:content_type]).to eq("application/octet-stream")
    end

    it "returns nil when nothing was uploaded" do
      expect(described_class.new(user, id).to_attachable(filename: "x", content_type: "video/mp4")).to be_nil
    end
  end

  it "#discard removes the scratch file" do
    upload = described_class.new(user, id)
    upload.append(StringIO.new("bytes"), first: true)
    expect(upload.exists?).to be(true)

    upload.discard
    expect(upload.exists?).to be(false)
  end
end
