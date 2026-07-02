require 'rails_helper'

RSpec.describe Serie, type: :model do
  it "has a valid factory" do
    expect(build(:serie)).to be_valid
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
  end

  describe "associations" do
    it { is_expected.to have_many(:seasons).dependent(:destroy) }
    it { is_expected.to have_many(:videos).through(:seasons) }
  end

  describe "attachments" do
    it { expect(described_class.reflect_on_attachment(:poster)).to be_present }
    it { expect(described_class.reflect_on_attachment(:backdrop)).to be_present }

    it "attaches a poster via the trait" do
      expect(build(:serie, :with_poster).poster).to be_attached
    end
  end

  describe ".recent" do
    it "orders by created_at descending" do
      older = create(:serie, created_at: 3.days.ago)
      newer = create(:serie, created_at: 1.hour.ago)
      expect(Serie.recent.to_a).to eq([newer, older])
    end
  end
end
