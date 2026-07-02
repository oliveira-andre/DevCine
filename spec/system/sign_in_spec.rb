require 'rails_helper'

RSpec.describe "Sign in", type: :system do
  it "renders the centered sign-in card" do
    visit new_session_path

    expect(page).to have_css("img.auth__logo")
    expect(page).to have_field("Login")
    expect(page).to have_field("Senha")
    expect(page).to have_button("Login")
    expect(page).to have_link("Sign Up")
  end

  it "signs a member in and lands on the home screen" do
    user = create(:user, password: "password123")

    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"

    expect(page).to have_current_path(root_path)
  end

  it "rejects a blocked member with a generic error" do
    user = create(:user, :blocked, password: "password123")

    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"

    expect(page).to have_current_path(new_session_path)
    expect(page).to have_content("Try another email address or password.")
  end
end
