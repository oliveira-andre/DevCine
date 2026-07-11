require 'rails_helper'

RSpec.describe Video, type: :model do
  subject { build(:video) }

  it "has a valid factory" do
    expect(build(:video)).to be_valid
  end

  describe "associations" do
    it { is_expected.to belong_to(:uploader).class_name("User") }
    it { is_expected.to have_many(:watch_progresses).dependent(:destroy) }
    it { is_expected.to have_many(:episodes).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    # duration_seconds is optional (unknown until processing) but positive when present
    it { is_expected.to validate_numericality_of(:duration_seconds).is_greater_than(0).allow_nil }
  end

  describe "maturity_rating" do
    it { is_expected.to define_enum_for(:maturity_rating).with_values(L: 0, A6: 1, A10: 2, A12: 3, A14: 4, A16: 5, A18: 6) }

    it "is valid without a duration (upload time)" do
      expect(build(:video, duration_seconds: nil)).to be_valid
    end
  end

  describe "attachments" do
    it { expect(described_class.reflect_on_attachment(:thumbnail)).to be_present }
    it { expect(described_class.reflect_on_attachment(:file)).to be_present }

    it "attaches a thumbnail via the trait" do
      expect(build(:video, :with_thumbnail).thumbnail).to be_attached
    end
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by created_at descending" do
        older = create(:video, created_at: 2.days.ago)
        newer = create(:video, created_at: 1.hour.ago)
        expect(Video.recent.to_a).to eq([newer, older])
      end
    end

    describe ".standalone_recent" do
      it "returns only standalone videos, most recent first" do
        standalone = create(:video, kind: :standalone)
        create(:video, kind: :feature)
        expect(Video.standalone_recent.to_a).to eq([standalone])
      end
    end
  end
end
