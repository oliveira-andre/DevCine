require 'rails_helper'

RSpec.describe User, type: :model do
  it "has a valid factory" do
    expect(build(:user)).to be_valid
  end

  describe "roles" do
    it { is_expected.to define_enum_for(:role).with_values(user: 0, admin: 1, blocked: 2) }

    it "exposes blocked? for blocked accounts" do
      expect(build(:user, :blocked)).to be_blocked
      expect(build(:user)).not_to be_blocked
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:watch_progresses).dependent(:destroy) }
    it { is_expected.to have_many(:uploaded_videos).class_name("Video").with_foreign_key(:uploader_id) }
    it { is_expected.to have_many(:liked_videos).through(:likes).source(:likeable) }

    it "liked_videos returns only videos the user liked" do
      user = create(:user)
      video = create(:video)
      create(:like, user: user, likeable: video)
      expect(user.liked_videos).to contain_exactly(video)
    end
  end

  describe "attachments" do
    it { expect(described_class.reflect_on_attachment(:avatar)).to be_present }
    it { expect(described_class.reflect_on_attachment(:cover)).to be_present }
  end

  describe "#initials" do
    it "derives up to two uppercase initials from the display name" do
      expect(build(:user, display_name: "Jane Doe").initials).to eq("JD")
    end

    it "falls back to the email local part when no display name" do
      expect(build(:user, display_name: nil, email_address: "john.smith@example.com").initials).to eq("JS")
    end
  end

  describe "#display_label" do
    it "prefers the display name" do
      expect(build(:user, display_name: "Neo").display_label).to eq("Neo")
    end
  end
end
