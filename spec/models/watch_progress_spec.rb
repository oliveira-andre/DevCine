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

      expect(WatchProgress.recent_for(user).to_a).to eq([newer, older])
    end
  end
end
