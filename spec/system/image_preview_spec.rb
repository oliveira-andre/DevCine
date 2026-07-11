require 'rails_helper'

RSpec.describe "Image previews", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "previews a selected thumbnail image on the upload form (US6)" do
    sign_in_as(create(:user, password: "password123"))
    visit account_path

    find(".account__action[aria-label='Upload video']").click
    expect(page).to have_css("dialog.modal[open]")

    attach_file "Thumbnail (optional)", Rails.root.join("spec/fixtures/files/sample_image.jpg")
    expect(page).to have_css("img.image-preview.is-visible")
  end
end
