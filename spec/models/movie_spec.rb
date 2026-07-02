require 'rails_helper'

RSpec.describe Movie, type: :model do
  it "has a valid factory" do
    expect(build(:movie)).to be_valid
  end

  describe "associations" do
    it { is_expected.to belong_to(:video) }
    it { is_expected.to belong_to(:trailer).class_name("Video").optional }
    it { is_expected.to have_many(:taggings) }
    it { is_expected.to have_many(:genres).through(:taggings) }
  end

  describe "attachments" do
    it { expect(described_class.reflect_on_attachment(:poster)).to be_present }
    it { expect(described_class.reflect_on_attachment(:backdrop)).to be_present }
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by created_at descending" do
        older = create(:movie, created_at: 3.days.ago)
        newer = create(:movie, created_at: 1.hour.ago)
        expect(Movie.recent.to_a).to eq([newer, older])
      end
    end

    describe ".hero" do
      it "returns at most the four most recent movies" do
        create_list(:movie, 5)
        expect(Movie.hero.size).to eq(4)
      end
    end
  end

  describe "#backdrop_image" do
    it "prefers the attached backdrop" do
      movie = build(:movie, :with_backdrop)
      expect(movie.backdrop_image).to eq(movie.backdrop)
    end

    it "falls back to backdrop_key when no file is attached" do
      movie = build(:movie, backdrop_key: "https://img.example.com/x.jpg")
      expect(movie.backdrop_image).to eq("https://img.example.com/x.jpg")
    end

    it "is nil when neither is present" do
      expect(build(:movie, backdrop_key: nil).backdrop_image).to be_nil
    end
  end
end
