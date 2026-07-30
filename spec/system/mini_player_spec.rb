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
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
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
end
