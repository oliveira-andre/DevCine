require 'rails_helper'

RSpec.describe WatchProgress, type: :model do
  it "has a valid factory" do
    expect(build(:watch_progress)).to be_valid
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:video) }
  end

  describe ".recent_for" do
    it "returns the user's progress ordered by most recently updated" do
      user = create(:user)
      older = create(:watch_progress, user: user, updated_at: 2.days.ago)
      newer = create(:watch_progress, user: user, updated_at: 5.minutes.ago)
      create(:watch_progress) # a different user's progress

      expect(WatchProgress.recent_for(user).to_a).to eq([ newer, older ])
    end
  end

  describe ".record!" do
    let(:user) { create(:user) }
    let(:video) { create(:video) }

    it "creates the resume position on first save" do
      expect {
        WatchProgress.record!(user, video, position: 42, duration: 600)
      }.to change(WatchProgress, :count).by(1)
      expect(WatchProgress.find_by(user:, video:).position_seconds).to eq(42)
    end

    it "updates in place on subsequent saves (one row per user+video)" do
      WatchProgress.record!(user, video, position: 42, duration: 600)
      expect {
        WatchProgress.record!(user, video, position: 90, duration: 600)
      }.not_to change(WatchProgress, :count)
      expect(WatchProgress.find_by(user:, video:).position_seconds).to eq(90)
    end

    it "marks completed within the last 5% of the runtime" do
      progress = WatchProgress.record!(user, video, position: 590, duration: 600)
      expect(progress.completed).to be(true)
    end

    it "clamps negative positions to zero" do
      progress = WatchProgress.record!(user, video, position: -10, duration: 600)
      expect(progress.position_seconds).to eq(0)
    end
  end
end
