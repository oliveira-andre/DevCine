require 'rails_helper'

RSpec.describe "Change password", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  def open_modal(user)
    sign_in_as(user)
    visit account_path
    find(".account__action[aria-label='Change password']").click
    expect(page).to have_css("dialog.modal[open]")
  end

  it "shows an error for a wrong current password and stays open" do
    open_modal(create(:user, password: "password123"))

    fill_in "Current password", with: "wrongpass"
    fill_in "New password", with: "newpass123"
    fill_in "Confirm new password", with: "newpass123"
    click_button "Update password"

    expect(page).to have_content("is incorrect")
    expect(page).to have_css("dialog.modal[open]")
  end

  it "disables submit while the new password and confirmation differ" do
    open_modal(create(:user, password: "password123"))

    fill_in "New password", with: "newpass123"
    fill_in "Confirm new password", with: "different"

    expect(page).to have_content("passwords do not match")
    expect(page).to have_button("Update password", disabled: true)
  end

  it "changes the password and closes the modal" do
    user = create(:user, password: "password123")
    open_modal(user)

    fill_in "Current password", with: "password123"
    fill_in "New password", with: "newpass123"
    fill_in "Confirm new password", with: "newpass123"
    click_button "Update password"

    expect(page).to have_no_css("dialog.modal[open]")
    expect(user.reload.authenticate("newpass123")).to be_truthy
  end
end
