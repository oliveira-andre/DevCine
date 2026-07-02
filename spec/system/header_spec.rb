require 'rails_helper'

RSpec.describe "Header", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "shows the logo, search, and a clickable avatar with the member's initials" do
    user = create(:user, password: "password123", display_name: "Jane Doe")
    sign_in_as(user)

    expect(page).to have_css(".site-header__brand .site-header__logo")
    expect(page).to have_css("a.avatar", text: "JD")
  end

  it "opens a full-screen search overlay on mobile" do
    sign_in_as(create(:user, password: "password123"))

    expect(page).to have_css(".search__overlay", visible: :all)
    expect(page).to have_no_css(".search__overlay .search__field", visible: :visible)

    find(".search__trigger").click

    expect(page).to have_css('.search__overlay[data-open="true"]')
    expect(page).to have_css(".search__overlay .search__field", visible: :visible)
  end

  it "shows the compact inline search field on desktop", :desktop do
    sign_in_as(create(:user, password: "password123"))

    expect(page).to have_css(".search__inline .search__field", visible: :visible)
    expect(page).to have_no_css(".search__trigger", visible: :visible)
  end
end
