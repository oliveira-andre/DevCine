require 'rails_helper'

RSpec.describe "PIN lockout", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "blocks the account and signs out after three wrong PINs" do
    user = create(:user, password: "password123")
    user.update!(pin: "1234", pin_confirmation: "1234")
    sign_in_as(user)
    visit account_path

    find(".account__action--lock").click
    expect(page).to have_css("dialog.modal[open]")

    # Assert the distinct decreasing count each round so Capybara waits for that
    # attempt's server round-trip (the .form-flash-alert node persists across
    # re-renders, so waiting on it alone races past the second attempt).
    fill_in "pin", with: "0000"
    click_button "Unlock"
    expect(page).to have_content("2 attempts remaining")

    fill_in "pin", with: "0000"
    click_button "Unlock"
    expect(page).to have_content("1 attempt remaining")

    fill_in "pin", with: "0000"
    click_button "Unlock"

    # Third strike: blocked + signed out, landing on sign-in.
    expect(page).to have_current_path(new_session_path)
    expect(user.reload).to be_blocked

    # Blocked accounts cannot sign back in.
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_content("Try another email address or password")
  end
end
