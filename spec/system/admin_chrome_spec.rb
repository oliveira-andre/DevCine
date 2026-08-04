require 'rails_helper'

# The admin area has its own header + left drawer nav, distinct from the app
# chrome. Crossing between the two must be a full navigation that swaps the
# whole chrome, not a #page-content stream that would leave the wrong header.
RSpec.describe "Admin chrome", type: :system do
  let(:admin) { create(:user, :admin, password: "password123") }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(admin) }

  it "swaps app chrome for admin chrome when entering from the user drawer" do
    visit root_path
    expect(page).to have_css(".site-header")

    find(".avatar").click
    within(".drawer") { click_link "Dashboard" }

    expect(page).to have_current_path(admin_dashboard_path)
    expect(page).to have_css(".admin-header")
    expect(page).to have_no_css(".site-header")
    expect(page).to have_no_css(".drawer") # the user drawer is gone
  end

  it "returns to the app chrome via Back to app" do
    visit admin_dashboard_path
    expect(page).to have_css(".admin-header")

    find(".admin-header__menu").click
    within(".admin-nav") { click_link "Back to app" }

    expect(page).to have_current_path(root_path)
    expect(page).to have_css(".site-header")
    expect(page).to have_no_css(".admin-header")
    expect(page).to have_no_css(".admin-nav")
  end

  it "opens and closes the nav drawer on mobile" do
    visit admin_dashboard_path

    expect(page).to have_no_css(".admin-nav.is-open")
    find(".admin-header__menu").click
    expect(page).to have_css(".admin-nav.is-open")

    find(".admin-nav__close").click
    expect(page).to have_no_css(".admin-nav.is-open")
  end

  it "navigates between admin sections and keeps the active state" do
    visit admin_dashboard_path

    find(".admin-header__menu").click
    within(".admin-nav") { click_link "Playlists" }

    expect(page).to have_current_path(admin_playlists_path)
    # The drawer closes on navigation, so the nav is off-canvas — assert on the
    # markup regardless of visibility.
    expect(page).to have_css(".admin-nav__link.is-active", text: "Playlists", visible: :all)
  end
end
