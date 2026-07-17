require 'rails_helper'

RSpec.describe VideoView, type: :model do
  let(:user) { create(:user) }

  describe ".record!" do
    it "creates a history entry on first watch" do
      video = create(:video)
      expect { VideoView.record!(user, video) }.to change { user.video_views.count }.by(1)
    end

    it "refreshes recency without duplicating on re-watch" do
      video = create(:video)
      first = VideoView.record!(user, video)
      again = VideoView.record!(user, video)
      expect(again.id).to eq(first.id)
      expect(user.video_views.where(video: video).count).to eq(1)
    end

    it "caps history at 300, pruning the oldest" do
      uploader = create(:user)
      videos = create_list(:video, 301, uploader: uploader)
      now = Time.current
      rows = videos.each_with_index.map do |v, i|
        { user_id: user.id, video_id: v.id, watched_at: now + i.seconds, created_at: now, updated_at: now }
      end
      VideoView.insert_all(rows)

      VideoView.prune!(user)

      expect(user.video_views.count).to eq(300)
      expect(user.video_views.where(video: videos.first)).to be_empty # oldest pruned
    end
  end

  describe ".history_for" do
    it "returns the user's videos newest-first" do
      old_v = create(:video)
      new_v = create(:video)
      VideoView.record!(user, old_v)
      user.video_views.find_by(video: old_v).update_column(:watched_at, 2.days.ago)
      VideoView.record!(user, new_v)

      expect(VideoView.history_for(user).map(&:video)).to eq([ new_v, old_v ])
    end
  end
end
