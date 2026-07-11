require 'rails_helper'

RSpec.describe "Inline name edit", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "edits the display name inline via a Turbo frame" do
    user = create(:user, password: "password123", display_name: "Old Name")
    sign_in_as(user)
    visit account_path

    click_link "Old Name"
    fill_in "Display name", with: "Brand New Name"
    click_button "Save"

    expect(page).to have_css(".account__name", text: "Brand New Name")
    expect(page).to have_no_field("Display name")
    expect(user.reload.display_name).to eq("Brand New Name")
  end

  it "does not show the editable name link on another member's public profile" do
    viewer = create(:user, password: "password123")
    owner = create(:user, display_name: "Owner Person")
    sign_in_as(viewer)

    visit public_account_path(slug: owner.handle)
    expect(page).to have_css("h1.account__name", text: "Owner Person")
    expect(page).to have_no_css(".account__name--editable")
  end
end
