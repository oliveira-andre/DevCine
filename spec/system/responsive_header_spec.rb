require 'rails_helper'

RSpec.describe "Responsive header", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "shows the wordmark logo and the search box on desktop", :desktop do
    sign_in_as(create(:user, password: "password123"))

    expect(page).to have_css(".site-header__logo--desktop", visible: :visible)
    expect(page).to have_no_css(".site-header__logo--mobile", visible: :visible)
    expect(page).to have_css(".search-box")
  end

  it "shows the mark-only logo on mobile" do
    sign_in_as(create(:user, password: "password123"))

    expect(page).to have_css(".site-header__logo--mobile", visible: :visible)
    expect(page).to have_no_css(".site-header__logo--desktop", visible: :visible)
    # No standalone search-icon button on mobile.
    expect(page).to have_no_css(".search__trigger")
  end

  it "navigates home when the logo is clicked" do
    sign_in_as(create(:user, password: "password123"))
    visit movies_path
    find(".site-header__brand").click
    expect(page).to have_current_path(root_path)
  end
end
