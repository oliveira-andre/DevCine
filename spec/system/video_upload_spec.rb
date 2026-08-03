require 'rails_helper'

RSpec.describe "Video upload", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  # The form saves itself as a draft once it has a title and a file, so the
  # upload is two steps now: pick the file, then Save to finish.
  it "uploads a standalone video that appears in Recent uploads" do
    user = create(:user, password: "password123")
    sign_in_as(user)
    visit account_path

    find(".account__action[aria-label='Upload video']").click
    expect(page).to have_css("dialog.modal[open]")

    fill_in "Title", with: "My Brand New Clip"
    attach_file "Video file", Rails.root.join("spec/fixtures/files/sample_video.mp4"), make_visible: true

    expect(page).to have_content("Finish your upload")
    click_button "Save"

    expect(page).to have_no_css("dialog.modal[open]")
    expect(page).to have_content("My Brand New Clip")
    expect(user.uploaded_videos.find_by(title: "My Brand New Clip")).to be_ready
  end

  it "holds the draft private until it is finished" do
    user = create(:user, password: "password123")
    sign_in_as(user)
    visit account_path

    find(".account__action[aria-label='Upload video']").click
    fill_in "Title", with: "Half Done Clip"
    attach_file "Video file", Rails.root.join("spec/fixtures/files/sample_video.mp4"), make_visible: true
    expect(page).to have_content("Finish your upload")

    draft = user.uploaded_videos.find_by(title: "Half Done Clip")
    expect(draft).to be_uploading
    expect(draft).to be_visibility_private
  end

  it "shows an error and stays open when the title is missing" do
    user = create(:user, password: "password123")
    sign_in_as(user)
    visit account_path

    find(".account__action[aria-label='Upload video']").click
    attach_file "Video file", Rails.root.join("spec/fixtures/files/sample_image.jpg"), make_visible: true
    # leave title blank; disable HTML5 required so the server validates
    page.execute_script("document.querySelector('input[name=\"video[title]\"]').removeAttribute('required')")
    click_button "Upload"

    expect(page).to have_css("dialog.modal[open]")
  end
end
