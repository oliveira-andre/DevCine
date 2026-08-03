require 'rails_helper'

# The suggestions arrive in a lazy Turbo Frame the form fetches on its own —
# there is no JavaScript driving the extraction. These run the real ffmpeg.
RSpec.describe "Thumbnail suggestions on the upload form", :ffmpeg, type: :system do
  let(:user) { create(:user, password: "password123") }

  SAMPLE_CLIP = Rails.root.join("spec/fixtures/files/sample_video.mp4")

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  def start_draft(title)
    visit account_path
    find(".account__action[aria-label='Upload video']").click
    fill_in "Title", with: title
    attach_file "Video file", SAMPLE_CLIP, make_visible: true
    expect(page).to have_content("Finish your upload")
  end

  before { sign_in_as(user) }

  it "swaps the spinner for three frames once ffmpeg answers" do
    start_draft("Framed Clip")

    expect(page).to have_css(".thumb-suggest__radio", count: 3, visible: :all)
    expect(page).to have_css(".thumb-suggest__img", count: 3)
  end

  it "preselects the first frame so saving always yields a thumbnail" do
    start_draft("Preselected Clip")
    expect(page).to have_css(".thumb-suggest__radio", count: 3, visible: :all)

    click_button "Save"

    expect(page).to have_no_css("dialog.modal[open]")
    video = user.uploaded_videos.find_by(title: "Preselected Clip")
    expect(video.thumbnail).to be_attached
    expect(video.thumbnail.filename.to_s).to eq("suggestion-01.jpg")
  end

  it "applies whichever frame the uploader picks" do
    start_draft("Picked Clip")
    expect(page).to have_css(".thumb-suggest__radio", count: 3, visible: :all)

    # The radio is visually hidden (kept reachable for keyboard/AT), so click
    # the label wrapping the frame — which is what a viewer actually clicks.
    all(".thumb-suggest__option")[2].click

    click_button "Save"

    expect(page).to have_no_css("dialog.modal[open]")
    video = user.uploaded_videos.find_by(title: "Picked Clip")
    expect(video.thumbnail.filename.to_s).to eq("suggestion-03.jpg")
    expect(video.thumbnail_candidates).not_to be_attached
  end

  # An unreadable file must not block the upload — the frame says so and the
  # uploader can still supply their own image.
  it "says so when no frames could be read" do
    visit account_path
    find(".account__action[aria-label='Upload video']").click
    fill_in "Title", with: "Not A Video"
    attach_file "Video file", Rails.root.join("spec/fixtures/files/sample_image.jpg"), make_visible: true
    expect(page).to have_content("Finish your upload")

    expect(page).to have_content("Couldn’t read any frames")

    click_button "Save"
    expect(page).to have_no_css("dialog.modal[open]")
    expect(user.uploaded_videos.find_by(title: "Not A Video")).to be_ready
  end
end
