require 'rails_helper'

RSpec.describe "PIN setup", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "creates a PIN with confirmation and then asks to enter it" do
    user = create(:user, password: "password123")
    sign_in_as(user)
    visit account_path

    find(".account__action--lock").click
    expect(page).to have_css("dialog.modal[open]")
    expect(page).to have_content("Create a 4–6 digit PIN")

    fill_in "PIN", with: "2468"
    fill_in "Confirm PIN", with: "2468"
    click_button "Create PIN"
    expect(page).to have_content("PIN created")

    expect(user.reload.pin?).to be(true)

    # Close the confirmation modal, then re-open: now it asks to ENTER the PIN.
    find(".modal__close").click
    expect(page).to have_no_css("dialog.modal[open]")
    find(".account__action--lock").click
    expect(page).to have_content(/enter your pin/i)
    expect(page).to have_no_content("2468")
  end

  it "shows an inline error on a mismatched confirmation" do
    user = create(:user, password: "password123")
    sign_in_as(user)
    visit account_path

    find(".account__action--lock").click
    fill_in "PIN", with: "1111"
    fill_in "Confirm PIN", with: "2222"
    click_button "Create PIN"

    expect(page).to have_css(".form-flash-alert")
    expect(user.reload.pin?).to be(false)
  end
end
