require 'rails_helper'

# US1: a series and a playlist render their videos as cards that open the player.
RSpec.describe "Collection show", type: :system do
  let(:user) { create(:user, password: "password123") }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(user) }

  it "shows a series with its episodes and opens the player on tap" do
    v1 = create(:video, :with_thumbnail, :with_file, title: "The Pilot", visibility: :public)
    v2 = create(:video, :with_thumbnail, title: "Episode Two", visibility: :public)
    serie = create(:serie)
    season = create(:season, serie: serie, position: 1)
    create(:episode, season: season, video: v1, position: 1)
    create(:episode, season: season, video: v2, position: 2)

    visit series_path(serie)

    expect(page).to have_css("main.collection")
    expect(page).to have_content(serie.title)
    expect(page).to have_content("The Pilot")
    expect(page).to have_content("Episode Two")

    within("turbo-frame#episodes") { click_link "The Pilot" }
    expect(page).to have_current_path(player_path(v1.slug), ignore_query: true)
  end

  it "shows a playlist with its videos in order" do
    a = create(:video, :with_thumbnail, title: "First Track", visibility: :public)
    b = create(:video, :with_thumbnail, title: "Second Track", visibility: :public)
    playlist = create(:playlist, user: user, visibility: :public)
    create(:playlist_item, playlist: playlist, video: a, position: 1)
    create(:playlist_item, playlist: playlist, video: b, position: 2)

    visit playlist_path(playlist)

    expect(page).to have_css("main.collection")
    expect(page).to have_content(playlist.title)
    expect(page).to have_content("First Track").and have_content("Second Track")
  end

  it "hides a restricted episode while locked" do
    open_v = create(:video, :with_thumbnail, title: "Public Ep", visibility: :public)
    gated = create(:video, :with_thumbnail, title: "Restricted Ep", visibility: :restricted, maturity_rating: :A18)
    serie = create(:serie)
    season = create(:season, serie: serie, position: 1)
    create(:episode, season: season, video: open_v, position: 1)
    create(:episode, season: season, video: gated, position: 2)

    visit series_path(serie)

    expect(page).to have_content("Public Ep")
    expect(page).to have_no_content("Restricted Ep")
  end
end
