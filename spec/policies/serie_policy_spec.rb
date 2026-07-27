require 'rails_helper'

RSpec.describe SeriePolicy do
  def ctx(unlocked: false)
    AuthContext.new(user: create(:user), pin_unlocked: unlocked)
  end

  # Build a serie whose single season holds the given videos.
  def serie_with(*videos)
    serie = create(:serie)
    season = create(:season, serie: serie, position: 1)
    videos.each_with_index { |v, i| create(:episode, season: season, video: v, position: i + 1) }
    serie
  end

  describe "#show? / Scope" do
    it "shows a mixed series (has a non-restricted episode) while locked" do
      serie = serie_with(create(:video, visibility: :public),
                         create(:video, visibility: :restricted, maturity_rating: :A18))
      expect(described_class.new(ctx, serie).show?).to be(true)
    end

    it "shows a series with no videos" do
      expect(described_class.new(ctx, create(:serie)).show?).to be(true)
    end

    it "hides an all-restricted series while locked but shows it when unlocked" do
      serie = serie_with(create(:video, visibility: :restricted, maturity_rating: :A18))
      expect(described_class.new(ctx, serie).show?).to be(false)
      expect(described_class.new(ctx(unlocked: true), serie).show?).to be(true)
    end
  end
end
