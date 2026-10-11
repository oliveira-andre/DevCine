require 'rails_helper'

# The rich prev/next controls must not drop fullscreen: a Turbo visit would
# reparent the permanent #mini-player and the browser exits fullscreen. While
# fullscreen they swap the neighbor IN PLACE (like the ending "Next") and the
# page/URL syncs once fullscreen exits. Headless Selenium cannot enter real
# fullscreen (see player_fullscreen_orientation_spec.rb), so
# document.fullscreenElement is stubbed and toggled from the spec.
RSpec.describe "Player prev/next while fullscreen", type: :system do
  let(:user) { create(:user, password: "password123") }
  let(:v1) { create(:video, :with_thumbnail, :with_file, title: "Pilot", visibility: :public) }
  let(:v2) { create(:video, :with_thumbnail, :with_file, title: "Second", visibility: :public) }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  def open_player(video, ready_button)
    visit player_path(video.slug)
    expect(page).to have_css("main.player")
    expect(page).to have_css("#mini-player[data-slug='#{video.slug}'] [data-mini-player-target='#{ready_button}']:not([hidden])", visible: :all)
  end

  def stub_fullscreen(on)
    page.execute_script(<<~JS)
      window.__fs = #{on};
      Object.defineProperty(document, "fullscreenElement", {
        configurable: true,
        get: () => (window.__fs ? document.querySelector("#mini-player") : null)
      });
    JS
  end

  def exit_fullscreen
    page.execute_script(%{window.__fs = false; document.dispatchEvent(new Event("fullscreenchange"))})
  end

  # Clicked via script: the rich controls are pointer-events:none until the
  # player chrome is active, which is not what this spec covers.
  def click_control(target)
    page.execute_script(%{document.querySelector('[data-mini-player-target="#{target}"]').click()})
  end

  before do
    serie = create(:serie)
    season = create(:season, serie: serie, position: 1)
    create(:episode, season: season, video: v1, position: 1)
    create(:episode, season: season, video: v2, position: 2)
    sign_in_as(user)
  end

  describe "next" do
    before { open_player(v1, "nextBtn") }

    it "advances in place while fullscreen and syncs the URL on exit" do
      stub_fullscreen(true)

      click_control("nextBtn")

      # The persistent player swapped to the next episode without a navigation.
      expect(page).to have_css("#mini-player[data-slug='#{v2.slug}']", visible: :all)
      expect(page).to have_current_path(player_path(v1.slug), ignore_query: true)

      exit_fullscreen

      expect(page).to have_current_path(player_path(v2.slug), ignore_query: true)
    end

    it "navigates straight to the next episode when not fullscreen" do
      stub_fullscreen(false)

      click_control("nextBtn")

      expect(page).to have_current_path(player_path(v2.slug), ignore_query: true)
    end
  end

  describe "previous" do
    before { open_player(v2, "prevBtn") }

    it "goes back in place while fullscreen and syncs the URL on exit" do
      stub_fullscreen(true)

      click_control("prevBtn")

      expect(page).to have_css("#mini-player[data-slug='#{v1.slug}']", visible: :all)
      expect(page).to have_current_path(player_path(v2.slug), ignore_query: true)

      exit_fullscreen

      expect(page).to have_current_path(player_path(v1.slug), ignore_query: true)
    end

    it "still restarts the episode when past the first seconds, even fullscreen" do
      stub_fullscreen(true)
      # The fixture file isn't real media, so the playhead is stubbed: 10s in.
      page.execute_script(<<~JS)
        window.__t = 10;
        Object.defineProperty(document.querySelector("#mini-player video"), "currentTime", {
          configurable: true, get: () => window.__t, set: (v) => { window.__t = v }
        });
      JS

      click_control("prevBtn")

      expect(page.evaluate_script("window.__t")).to eq(0)
      expect(page).to have_css("#mini-player[data-slug='#{v2.slug}']", visible: :all)
      expect(page).to have_current_path(player_path(v2.slug), ignore_query: true)
    end

    it "navigates straight to the previous episode when not fullscreen" do
      stub_fullscreen(false)

      click_control("prevBtn")

      expect(page).to have_current_path(player_path(v1.slug), ignore_query: true)
    end
  end

  describe "previous that cannot play in place" do
    it "falls back to visiting its page instead of doing nothing" do
      blank = create(:video, title: "No File Yet", visibility: :public) # no playable file
      v3 = create(:video, :with_thumbnail, :with_file, title: "Third", visibility: :public)
      season = create(:season, serie: create(:serie), position: 1)
      create(:episode, season: season, video: blank, position: 1)
      create(:episode, season: season, video: v3, position: 2)

      open_player(v3, "prevBtn")
      stub_fullscreen(true)

      click_control("prevBtn")

      expect(page).to have_current_path(player_path(blank.slug), ignore_query: true)
    end
  end
end
