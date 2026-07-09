require 'rails_helper'

RSpec.describe "Navigation drawer", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "opens from the avatar with the nav items and sign out" do
    sign_in_as(create(:user, password: "password123"))

    find(".avatar").click
    expect(page).to have_css(".drawer.is-open")

    within(".drawer__panel") do
      %w[Home Lives Videos Movies Series Account].each do |label|
        expect(page).to have_link(label)
      end
      expect(page).to have_button("Sign out")
    end
  end

  it "navigates to a section from the drawer" do
    sign_in_as(create(:user, password: "password123"))
    find(".avatar").click
    within(".drawer__panel") { click_link "Movies" }
    expect(page).to have_current_path(movies_path)
  end

  it "closes on Escape without navigating" do
    sign_in_as(create(:user, password: "password123"))
    find(".avatar").click
    expect(page).to have_css(".drawer.is-open")

    find("body").send_keys(:escape)
    expect(page).to have_no_css(".drawer.is-open")
    expect(page).to have_current_path(root_path)
  end

  it "signs out from the drawer" do
    sign_in_as(create(:user, password: "password123"))
    find(".avatar").click
    within(".drawer__panel") { click_button "Sign out" }
    expect(page).to have_current_path(new_session_path)
  end
end
