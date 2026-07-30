require 'rails_helper'

# US3: seasons carousel switches only the episodes frame.
RSpec.describe "Season switching", type: :system do
  let(:user) { create(:user, password: "password123") }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(user) }

  it "lists seasons in order and swaps only the episodes region on select" do
    s1v = create(:video, :with_thumbnail, title: "Season One Ep", visibility: :public)
    s2v = create(:video, :with_thumbnail, title: "Season Two Ep", visibility: :public)
    serie = create(:serie)
    season1 = create(:season, serie: serie, position: 1, name: "Season 1")
    season2 = create(:season, serie: serie, position: 2, name: "Season 2")
    create(:episode, season: season1, video: s1v, position: 1)
    create(:episode, season: season2, video: s2v, position: 1)

    visit series_path(serie)

    # Seasons appear in order; season 1 active by default.
    within(".seasons") do
      expect(page).to have_link("Season 1")
      expect(page).to have_link("Season 2")
      expect(page).to have_css(".season-chip.is-active", text: "Season 1")
    end
    expect(page).to have_content("Season One Ep")

    # Select season 2 → it becomes active and only the episodes region updates.
    click_link "Season 2"
    within("turbo-frame#episodes") do
      expect(page).to have_content("Season Two Ep")
      expect(page).to have_no_content("Season One Ep")
    end
    within(".seasons") { expect(page).to have_css(".season-chip.is-active", text: "Season 2") }
    # Header/hero stayed (no full reload).
    expect(page).to have_css("main.collection h1", text: serie.title)
  end

  it "shows no season carousel on a playlist" do
    v = create(:video, :with_thumbnail, title: "Track", visibility: :public)
    playlist = create(:playlist, user: user, visibility: :public)
    create(:playlist_item, playlist: playlist, video: v, position: 1)

    visit playlist_path(playlist)

    expect(page).to have_css("main.collection")
    expect(page).to have_no_css(".seasons")
  end
end
