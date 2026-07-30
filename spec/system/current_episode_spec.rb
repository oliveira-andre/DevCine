require 'rails_helper'

# US5: the current episode (most-recently-watched) is blue-outlined + play icon.
RSpec.describe "Current episode marker", type: :system do
  let(:user) { create(:user, password: "password123") }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  def serie_with(*videos)
    serie = create(:serie)
    season = create(:season, serie: serie, position: 1)
    videos.each_with_index { |v, i| create(:episode, season: season, video: v, position: i + 1) }
    serie
  end

  before { sign_in_as(user) }

  it "marks exactly the most-recently-watched episode and matches the hero" do
    v1 = create(:video, :with_thumbnail, title: "One", visibility: :public)
    v2 = create(:video, :with_thumbnail, title: "Two", visibility: :public)
    serie = serie_with(v1, v2)
    VideoView.record!(user, v2)

    visit series_path(serie)

    # Exactly one card marked, and it is the watched one.
    expect(page).to have_css(".episode-card--current", count: 1)
    within(".episode-card--current") do
      expect(page).to have_content("Two")
      expect(page).to have_css(".episode-card__state")
    end
    # The hero links to the current video's player and names it.
    expect(page).to have_css(".collection__hero-link[href^='#{player_path(v2.slug)}']")
    expect(page).to have_css(".collection__hero-caption", text: "Two")
  end

  it "marks no card when the viewer has no history in the collection" do
    v1 = create(:video, :with_thumbnail, title: "One", visibility: :public)
    serie = serie_with(v1)

    visit series_path(serie)

    expect(page).to have_css(".episode-card")
    expect(page).to have_no_css(".episode-card--current")
  end
end
