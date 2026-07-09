require 'rails_helper'

RSpec.describe "Section infinite scroll", type: :system, desktop: true do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "appends the next page when the list is scrolled to the bottom" do
    create_list(:movie, 25)
    sign_in_as(create(:user, password: "password123"))

    visit movies_path
    expect(page).to have_css(".poster-card", count: 20) # bounded first page

    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")

    # The lazy end-of-list frame loads page 2 (5 more) and appends.
    expect(page).to have_css(".poster-card", count: 25)
  end

  it "stops at the last page with no residual loader" do
    create_list(:movie, 10)
    sign_in_as(create(:user, password: "password123"))

    visit movies_path
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")

    expect(page).to have_css(".poster-card", count: 10)
    expect(page).to have_no_css("turbo-frame[src]:not([complete])")
  end
end
