require 'rails_helper'

RSpec.describe Comment, type: :model do
  it { is_expected.to validate_presence_of(:body) }

  describe ".for_video" do
    it "returns the video's comments newest-first" do
      video = create(:video)
      old_c = create(:comment, video: video, created_at: 2.hours.ago)
      new_c = create(:comment, video: video, created_at: 1.minute.ago)
      create(:comment) # a different video

      expect(Comment.for_video(video).to_a).to eq([ new_c, old_c ])
    end
  end

  describe "#long?" do
    it "is true with more than 3 paragraphs" do
      body = (1..4).map { |i| "Paragraph #{i}." }.join("\n\n")
      expect(build(:comment, body: body).long?).to be(true)
    end

    it "is false with 3 or fewer paragraphs" do
      expect(build(:comment, body: "One.\n\nTwo.\n\nThree.").long?).to be(false)
    end
  end
end
