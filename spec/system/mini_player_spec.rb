require 'rails_helper'

# Feature 010: the persistent mini-player. These specs assert the observable DOM
# state transitions (expanded ↔ docked, close, toggle persistence). Actual media
# playback continuity across navigation is verified live via Playwright (headless
# Selenium can't reliably decode/autoplay media), consistent with feature 005.
RSpec.describe "Persistent mini-player", type: :system do
  let(:user) { create(:user, password: "password123") }
  let!(:video) { create(:video, :with_thumbnail, :with_file, title: "Docker Clip", visibility: :public) }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(user) }

  it "expands on the player page and docks when navigating away, then re-expands" do
    visit player_path(video.slug)
    expect(page).to have_css("#mini-player.mini-player--expanded", visible: :all)

    # Turbo Drive navigation (header brand → home) keeps the permanent player.
    find(".site-header__brand").click
    expect(page).to have_css("main.home")
    expect(page).to have_css("#mini-player.mini-player--docked")

    # Returning to the player page re-expands the same host.
    visit player_path(video.slug)
    expect(page).to have_css("#mini-player.mini-player--expanded", visible: :all)
  end

  it "opens the video's player page when the docked player body is clicked" do
    visit player_path(video.slug)
    find(".site-header__brand").click
    expect(page).to have_css("#mini-player.mini-player--docked")

    # Click the docked body (top-left corner — away from the centered play button
    # and the top-right close) → navigate to the full player.
    find("#mini-player").click(x: 12, y: 12, offset: :top_left)
    expect(page).to have_current_path(player_path(video.slug), ignore_query: true)
    expect(page).to have_css("#mini-player.mini-player--expanded", visible: :all)
  end

  it "streams navigation without touching the player and keeps real URLs" do
    visit videos_path
    expect(page).to have_css("main.listing")
    # Stream-nav to the player via a poster card, then back out via the header.
    first(".poster-card__link").click
    expect(page).to have_css("#mini-player.mini-player--expanded", visible: :all)
    expect(page).to have_current_path(%r{/playing/}, ignore_query: true) # pushState shim
    find(".site-header__brand").click
    expect(page).to have_css("main.home")
    expect(page).to have_current_path(root_path)
    expect(page).to have_css("#mini-player.mini-player--docked")
  end

  it "minimizes with the i key and returns to the last page (back_navigation)" do
    visit videos_path
    expect(page).to have_css("main.listing")
    first(".poster-card__link").click
    expect(page).to have_css("#mini-player.mini-player--expanded", visible: :all)

    find("body").send_keys("i")
    # Back on /movies, player docked, still alive.
    expect(page).to have_current_path(videos_path)
    expect(page).to have_css("main.listing")
    expect(page).to have_css("#mini-player.mini-player--docked")
  end

  it "closes the docked player and does not resurrect it on further navigation" do
    visit player_path(video.slug)
    find(".site-header__brand").click
    expect(page).to have_css("#mini-player.mini-player--docked")

    find(".mini-player__close").click
    expect(page).to have_css("#mini-player", visible: :hidden)

    find(".drawer, body").click if page.has_css?(".avatar")
    # Navigating elsewhere: still no visible player until a new video is opened.
    visit movies_path rescue nil
  end

  describe "autoplay preference (US5)" do
    it "defaults on, toggles off, and persists" do
      visit player_path(video.slug)
      expect(page).to have_css(".player__autoplay.is-on")

      find(".player__autoplay").click
      expect(page).to have_css(".player__autoplay:not(.is-on)")

      visit player_path(video.slug)
      expect(page).to have_css(".player__autoplay:not(.is-on)") # persisted
      expect(user.reload.autoplay).to be(false)
    end
  end

  # The natural end of a video (autoplay on). `ended` is dispatched by hand —
  # headless Selenium can't play the media through (see header).
  describe "autoplay advance (US5)" do
    def end_video
      page.execute_script(%{document.querySelector("#mini-player video").dispatchEvent(new Event("ended"))})
    end

    it "swaps the next episode into the DOCKED player without leaving the page" do
      v1 = create(:video, :with_thumbnail, :with_file, title: "Ep One", visibility: :public)
      v2 = create(:video, :with_thumbnail, :with_file, title: "Ep Two", visibility: :public)
      season = create(:season, serie: create(:serie), position: 1)
      create(:episode, season: season, video: v1, position: 1)
      create(:episode, season: season, video: v2, position: 2)

      visit player_path(v1.slug)
      expect(page).to have_css("#mini-player[data-slug='#{v1.slug}']", visible: :all)
      find(".site-header__brand").click
      expect(page).to have_css("#mini-player.mini-player--docked")

      end_video

      expect(page).to have_css("#mini-player.mini-player--docked[data-slug='#{v2.slug}']")
      expect(page).to have_current_path(root_path)
    end

    it "navigates the EXPANDED player to a recommendation when there is no sequence next" do
      current = create(:video, :with_thumbnail, :with_file, title: "Solo", visibility: :public, kind: :standalone)
      create(:video, :with_thumbnail, :with_file, title: "Another", visibility: :public, kind: :standalone)

      visit player_path(current.slug)
      expect(page).to have_css("#mini-player.mini-player--expanded[data-slug='#{current.slug}']", visible: :all)

      end_video

      expect(page).to have_no_current_path(player_path(current.slug), ignore_query: true)
      expect(page).to have_current_path(%r{/playing/}, ignore_query: true)
    end
  end
end
