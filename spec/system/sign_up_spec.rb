require 'rails_helper'

RSpec.describe "Sign up", type: :system do
  it "disables the submit button and shows a message while passwords do not match" do
    visit new_registration_path

    fill_in "Login", with: "brand.new@example.com"
    fill_in "Senha", with: "password123"
    fill_in "Confirme a Senha", with: "different"

    expect(page).to have_content("passwords do not match")
    expect(page).to have_button("Create account", disabled: true)

    # Correcting the confirmation re-enables the button and clears the message.
    fill_in "Confirme a Senha", with: "password123"
    expect(page).to have_no_content("passwords do not match")
    expect(page).to have_button("Create account", disabled: false)
  end

  it "creates a 'user' account and lands on the home screen" do
    visit new_registration_path

    fill_in "Login", with: "brand.new@example.com"
    fill_in "Senha", with: "password123"
    fill_in "Confirme a Senha", with: "password123"
    click_button "Create account"

    expect(page).to have_current_path(root_path)
    expect(User.find_by(email_address: "brand.new@example.com").role).to eq("user")
  end
end
