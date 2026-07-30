require 'rails_helper'

# US4: a season/playlist with more than one page appends batches on scroll.
RSpec.describe "Collection infinite scroll", type: :system do
  let(:user) { create(:user, password: "password123") }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(user) }

  # Page size is 12 (SeriesController/PlaylistsController); 15 forces a 2nd page.
  it "appends the next batch of episodes on scroll (series)" do
    serie = create(:serie)
    season = create(:season, serie: serie, position: 1)
    15.times do |i|
      v = create(:video, :with_thumbnail, title: format("Episode %02d", i + 1), visibility: :public)
      create(:episode, season: season, video: v, position: i + 1)
    end

    visit series_path(serie)
    expect(page).to have_content("Episode 01")

    # The last item is on page 2 — scrolling brings the lazy frame into view.
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    expect(page).to have_content("Episode 15")
    expect(page).to have_css(".episode-card", minimum: 15)
  end

  it "appends the next batch on scroll (playlist) and ends cleanly" do
    playlist = create(:playlist, user: user, visibility: :public)
    15.times do |i|
      v = create(:video, :with_thumbnail, title: format("Track %02d", i + 1), visibility: :public)
      create(:playlist_item, playlist: playlist, video: v, position: i + 1)
    end

    visit playlist_path(playlist)
    expect(page).to have_content("Track 01")

    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    expect(page).to have_content("Track 15")
    # After the final batch, no loader remains.
    expect(page).to have_no_css(".pagination-loader")
  end
end
