require 'rails_helper'

# US4: unlock survives in-app (Turbo) navigation but dies on a hard refresh.
RSpec.describe "PIN unlock session", type: :system do
  let(:user) { create(:user, password: "password123") }
  let!(:restricted) do
    create(:video, :with_thumbnail, :with_file, title: "Locked Away 88", kind: :standalone,
           visibility: :restricted, maturity_rating: :A18)
  end

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  def unlock!
    visit account_path
    find(".account__action--lock").click
    fill_in "pin", with: "1234"
    click_button "Unlock"
    expect(page).to have_no_css("dialog.modal[open]")
  end

  # In-app navigation via Turbo (drawer link) — carries the X-Pin-Unlock header.
  def navigate_to_videos
    find("button[aria-label='Open menu']").click
    within(".drawer") { click_link "Videos" }
    expect(page).to have_css("main.listing")
  end

  before { user.update!(pin: "1234", pin_confirmation: "1234") }

  it "stays unlocked across in-app navigation, then relocks on hard refresh" do
    sign_in_as(user)

    # Locked: restricted title absent from the videos listing.
    navigate_to_videos
    expect(page).to have_no_content("Locked Away 88")

    unlock! # server verifies + client holds the token in memory

    # In-app Turbo navigation keeps the unlock (the header rides along).
    navigate_to_videos
    expect(page).to have_content("Locked Away 88")

    # Hard refresh loses the in-memory token → relocked.
    page.driver.browser.navigate.refresh
    expect(page).to have_no_content("Locked Away 88")
  end
end
