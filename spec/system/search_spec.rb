require 'rails_helper'

RSpec.describe "Search", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
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

  it "browses a category from the search page" do
    Genre.create!(name: "Drama")
    sign_in_as(create(:user, password: "password123"))
    visit search_path

    click_link "Drama"
    expect(page).to have_current_path(/genres/)
  end
end
