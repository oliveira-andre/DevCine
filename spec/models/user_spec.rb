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

  describe "restricted-content PIN (feature 006)" do
    let(:user) { create(:user) }

    it "stores the PIN as a bcrypt digest and verifies via authenticate_pin" do
      user.update!(pin: "1234", pin_confirmation: "1234")
      expect(user.pin_digest).to be_present
      expect(user.pin_digest).not_to include("1234")
      expect(user.authenticate_pin("1234")).to be_truthy
      expect(user.authenticate_pin("9999")).to be(false)
      expect(user.pin?).to be(true)
    end

    it "rejects non-numeric or wrong-length PINs" do
      expect(user.update(pin: "12a4", pin_confirmation: "12a4")).to be(false)
      expect(user.update(pin: "123", pin_confirmation: "123")).to be(false)
      expect(user.update(pin: "1234567", pin_confirmation: "1234567")).to be(false)
      expect(user.errors[:pin]).to be_present
    end

    it "rejects a mismatched confirmation" do
      expect(user.update(pin: "1234", pin_confirmation: "4321")).to be(false)
      expect(user.reload.pin?).to be(false)
    end

    it "defaults PIN_MAX_ATTEMPTS to 3" do
      expect(User::PIN_MAX_ATTEMPTS).to eq(3)
    end

    it "counts failures and blocks at the limit" do
      expect(user.register_failed_pin_attempt!).to eq(:failed)
      expect(user.register_failed_pin_attempt!).to eq(:failed)
      expect(user.remaining_pin_attempts).to eq(1)
      expect(user.register_failed_pin_attempt!).to eq(:blocked)
      expect(user.reload).to be_blocked
    end

    it "resets the counter on success" do
      user.register_failed_pin_attempt!
      user.reset_pin_attempts!
      expect(user.reload.pin_attempts).to eq(0)
    end
  end

  describe "'Videos you liked' playlist (feature 005)" do
    it "creates a private playlist on account creation" do
      user = create(:user)
      playlist = user.playlists.find_by(title: User::LIKED_PLAYLIST_TITLE)
      expect(playlist).to be_present
      expect(playlist).to be_visibility_private
    end

    it "#liked_playlist lazily creates it for legacy users and is idempotent" do
      user = create(:user)
      user.playlists.destroy_all # simulate a user created before the feature
      playlist = user.liked_playlist
      expect(playlist.title).to eq(User::LIKED_PLAYLIST_TITLE)
      expect(playlist).to be_visibility_private
      expect(user.liked_playlist.id).to eq(playlist.id)
    end
  end
end
