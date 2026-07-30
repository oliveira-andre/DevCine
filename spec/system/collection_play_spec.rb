require 'rails_helper'

# US2: Play/Continue opens the first video (no history) or resumes the current one.
RSpec.describe "Collection play/continue", type: :system do
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

  it "Play opens the first episode when nothing has been watched" do
    v1 = create(:video, :with_thumbnail, :with_file, title: "Pilot", visibility: :public)
    v2 = create(:video, :with_thumbnail, :with_file, title: "Two", visibility: :public)
    serie = serie_with(v1, v2)

    visit series_path(serie)
    expect(page).to have_link("Play")
    click_link "Play"
    expect(page).to have_current_path(player_path(v1.slug), ignore_query: true)
  end

  it "Continue resumes the most-recently-watched episode" do
    v1 = create(:video, :with_thumbnail, :with_file, title: "Pilot", visibility: :public)
    v2 = create(:video, :with_thumbnail, :with_file, title: "Two", visibility: :public)
    serie = serie_with(v1, v2)
    WatchProgress.record!(user, v2, position: 30, duration: 600)
    VideoView.record!(user, v2)

    visit series_path(serie)
    expect(page).to have_link("Continue")
    click_link "Continue"
    expect(page).to have_current_path(player_path(v2.slug), ignore_query: true)
  end
end
