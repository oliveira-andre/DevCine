require 'rails_helper'

RSpec.describe "Search", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "routes the header search to /search with a focused input and categories" do
    Genre.create!(name: "Drama")
    sign_in_as(create(:user, password: "password123"))

    find(".search-box").click

    expect(page).to have_current_path(search_path)
    expect(page).to have_css("input.search-page__input:focus")
    expect(page).to have_link("Drama")
  end

  # The page has its own input, so the header link would be a second search box.
  # The header is never re-rendered by stream navigation, so leaving the page
  # must bring the link back.
  it "hides the header search link on /search and shows it again after leaving" do
    sign_in_as(create(:user, password: "password123"))

    find(".search-box").click
    expect(page).to have_css("input.search-page__input:focus")
    expect(page).to have_no_css(".site-header .search-box")

    find(".site-header__brand").click
    expect(page).to have_css("main.home")
    expect(page).to have_css(".site-header .search-box")
  end

  it "browses a category from the search page" do
    Genre.create!(name: "Drama")
    sign_in_as(create(:user, password: "password123"))
    visit search_path

    click_link "Drama"
    expect(page).to have_current_path(/genres/)
  end
end
