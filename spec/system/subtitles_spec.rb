require 'rails_helper'

# Feature 012: the subtitle icon, settings popup, persistence, and language menu.
# Cue-over-video rendering depends on real media decode and is verified live via
# Playwright; these specs cover the control + persistence layer (headless-safe).
RSpec.describe "Subtitles", type: :system do
  let(:user) { create(:user, password: "password123") }
  let!(:video) { create(:video, :with_thumbnail, :with_file, title: "Sub Clip", visibility: :public) }
  let!(:track) { create(:subtitle, :with_file, video: video, language: :english, is_default: true) }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(user) }

  it "toggles on, opens the popup on second tap, and persists" do
    visit player_path(video.slug)
    expect(page).to have_css(".subtitles__toggle")
    expect(page).to have_no_css(".subtitles__toggle.is-on")

    find(".subtitles__toggle").click # off → on
    expect(page).to have_css(".subtitles__toggle.is-on")
    sleep 0.5 # let the debounced PATCH land
    expect(user.reload.subtitles_enabled).to be(true)

    find(".subtitles__toggle").click # on → open popup
    expect(page).to have_css(".subtitles__popup", visible: true)
    within(".subtitles__popup") do
      expect(page).to have_button("Turn off subtitles")
    end
  end

  it "has the appearance controls and can turn subtitles off" do
    user.update!(subtitles_enabled: true)
    visit player_path(video.slug)
    find(".subtitles__toggle").click # opens popup (already on)

    within(".subtitles__popup") do
      expect(page).to have_css("[data-controller='color-picker']", count: 2) # text + background
      expect(page).to have_field("Transparent", type: "checkbox")
      expect(page).to have_css("input[type='range']")       # font size
      click_button "Turn off subtitles"
    end
    expect(page).to have_no_css(".subtitles__toggle.is-on")
    sleep 0.5
    expect(user.reload.subtitles_enabled).to be(false)
  end

  it "shows a language menu for a multi-track video" do
    create(:subtitle, :with_file, video: video, language: :spanish)
    user.update!(subtitles_enabled: true)
    visit player_path(video.slug)
    find(".subtitles__toggle").click

    within(".subtitles__popup") do
      expect(page).to have_css("[data-subtitle-settings-target='languageRow']", visible: true)
      expect(page).to have_select(options: ["English", "Spanish"])
    end
  end

  it "shows the language menu for a single-track video too" do
    # An empty popup reads as "no subtitles" — the one track must be visible
    # (auto-selected) even though there is nothing to switch to.
    user.update!(subtitles_enabled: true)
    visit player_path(video.slug)
    find(".subtitles__toggle").click

    within(".subtitles__popup") do
      expect(page).to have_css("[data-subtitle-settings-target='languageRow']", visible: true)
      expect(page).to have_select(options: ["English"])
    end
  end

  describe "admin manager (US4)" do
    let(:admin) { create(:user, :admin, password: "password123") }

    it "opens the subtitle manager modal from the video's detail page with tracks + dropzone" do
      page.driver.browser.manage.delete_all_cookies # drop the regular-user session
      sign_in_as(admin)
      # The videos list links to each video's detail page; the subtitle manager
      # lives there (feature 013 reorganised the admin videos section).
      visit admin_video_path(video)
      find("a[href*='#{video.slug}/subtitles/new']").click

      within("turbo-frame#modal") do
        expect(page).to have_content("Subtitles — #{video.title}")
        expect(page).to have_content("English")              # existing track
        expect(page).to have_content("captions.srt")         # its filename
        expect(page).to have_css(".admin-live__action--danger") # trash
        expect(page).to have_select("subtitle_language")
        expect(page).to have_css(".dropzone")                # SRT drag & drop
      end
    end
  end
end
