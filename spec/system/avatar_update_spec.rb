require 'rails_helper'

RSpec.describe "Avatar update", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "opens from the avatar, previews the selection, and saves" do
    user = create(:user, password: "password123")
    sign_in_as(user)
    visit account_path

    find(".account__avatar-link").click
    expect(page).to have_css("dialog.modal[open]")

    attach_file "Profile picture", Rails.root.join("spec/fixtures/files/sample_image.jpg")
    expect(page).to have_css("img.image-preview.is-visible")

    click_button "Save"
    expect(page).to have_no_css("dialog.modal[open]")
    expect(user.reload.avatar).to be_attached
  end
end
