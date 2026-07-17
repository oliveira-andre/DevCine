require 'rails_helper'

RSpec.describe "Movie & Serie policy scopes" do
  def context(unlocked: false)
    AuthContext.new(user: create(:user), pin_unlocked: unlocked)
  end

  describe MoviePolicy::Scope do
    it "hides a movie while locked when its feature video is restricted" do
      visible = create(:movie, video: create(:video, visibility: :public))
      hidden = create(:movie, video: create(:video, visibility: :restricted, maturity_rating: :A18))

      expect(described_class.new(context, Movie).resolve).to contain_exactly(visible)
      expect(described_class.new(context(unlocked: true), Movie).resolve)
        .to contain_exactly(visible, hidden)
    end
  end

  describe SeriePolicy::Scope do
    def serie_with_videos(*visibilities)
      serie = Serie.create!(title: "Serie #{SecureRandom.hex(3)}")
      season = serie.seasons.create!(name: "Season 1", position: 1)
      visibilities.each_with_index do |visibility, i|
        video = create(:video, visibility: visibility,
                       maturity_rating: visibility == :restricted ? :A18 : :L)
        season.episodes.create!(video: video, title: "Ep #{i + 1}", position: i + 1)
      end
      serie
    end

    it "hides only series whose videos are all restricted, while locked" do
      no_videos = Serie.create!(title: "Empty Serie")
      mixed = serie_with_videos(:public, :restricted)
      all_restricted = serie_with_videos(:restricted, :restricted)

      locked = described_class.new(context, Serie).resolve
      expect(locked).to contain_exactly(no_videos, mixed)

      unlocked = described_class.new(context(unlocked: true), Serie).resolve
      expect(unlocked).to contain_exactly(no_videos, mixed, all_restricted)
    end
  end
end
