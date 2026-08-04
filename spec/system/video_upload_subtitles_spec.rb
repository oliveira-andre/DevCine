require 'rails_helper'

# Subtitles are filled in on the second step: choosing the video file saves the
# draft and swaps the form into finish mode, and the subtitle rows live there.
RSpec.describe "Uploading subtitles with a video", type: :system do
  let(:user) { create(:user, password: "password123") }

  SAMPLE_VIDEO = Rails.root.join("spec/fixtures/files/sample_video.mp4")
  SAMPLE_IMAGE = Rails.root.join("spec/fixtures/files/sample_image.jpg")
  SAMPLE_SRT = Rails.root.join("spec/fixtures/files/sample_captions.srt")

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  # Opens the modal and gets as far as the finish step, where subtitles live.
  def start_draft(title)
    visit account_path
    find(".account__action[aria-label='Upload video']").click
    expect(page).to have_css("dialog.modal[open]")

    fill_in "Title", with: title
    attach_file "Video file", SAMPLE_VIDEO, make_visible: true
    expect(page).to have_content("Finish your upload")
  end

  # Each row's inputs are named by index; every row shares the same labels, so
  # target them positionally.
  def subtitle_row(index)
    all("[data-nested-fields-row]")[index]
  end

  before { sign_in_as(user) }

  it "offers one subtitle slot, which can be left alone" do
    start_draft("No Captions Clip")

    expect(page).to have_css("[data-nested-fields-row]", count: 1)
    click_button "Save"

    expect(page).to have_no_css("dialog.modal[open]")
    video = user.uploaded_videos.find_by(title: "No Captions Clip")
    expect(video).to be_ready
    expect(video.subtitles).to be_empty
  end

  it "saves a subtitle track alongside the video" do
    start_draft("Captioned Clip")

    within(subtitle_row(0)) do
      attach_file SAMPLE_SRT, make_visible: true
      select "Portuguese", from: "video[subtitles_attributes][0][language]"
    end
    click_button "Save"

    expect(page).to have_no_css("dialog.modal[open]")
    video = user.uploaded_videos.find_by(title: "Captioned Clip")
    expect(video.subtitles.count).to eq(1)
    expect(video.subtitles.first.language).to eq("portuguese")
  end

  it "adds a second subtitle row and saves both tracks" do
    start_draft("Bilingual Clip")

    within(subtitle_row(0)) do
      attach_file SAMPLE_SRT, make_visible: true
      select "English", from: "video[subtitles_attributes][0][language]"
    end

    click_button "Add another subtitle"
    expect(page).to have_css("[data-nested-fields-row]", count: 2)

    within(subtitle_row(1)) do
      attach_file SAMPLE_SRT, make_visible: true
      select "Spanish", from: "video[subtitles_attributes][1][language]"
    end
    click_button "Save"

    expect(page).to have_no_css("dialog.modal[open]")
    video = user.uploaded_videos.find_by(title: "Bilingual Clip")
    expect(video.subtitles.pluck(:language)).to contain_exactly("english", "spanish")
  end

  it "drops a row that was added and then removed" do
    start_draft("Row Removal Clip")

    click_button "Add another subtitle"
    expect(page).to have_css("[data-nested-fields-row]", count: 2)

    within(subtitle_row(1)) { find(".subtitle-fields__remove").click }

    expect(page).to have_css("[data-nested-fields-row]", count: 1)
  end

  it "keeps a row available after removing the only one" do
    start_draft("Last Row Clip")

    within(subtitle_row(0)) { find(".subtitle-fields__remove").click }

    expect(page).to have_css("[data-nested-fields-row]", count: 1)
  end

  it "stops adding rows at the cap" do
    start_draft("Capped Clip")

    4.times { click_button "Add another subtitle" }

    expect(page).to have_css("[data-nested-fields-row]", count: 5)
    expect(page).to have_no_button("Add another subtitle")
  end

  it "reports a subtitle that is not an .srt and keeps the modal open" do
    start_draft("Bad Captions Clip")

    within(subtitle_row(0)) do
      attach_file SAMPLE_IMAGE, make_visible: true # a .jpg, not a .srt
      select "English", from: "video[subtitles_attributes][0][language]"
    end
    click_button "Save"

    expect(page).to have_css("dialog.modal[open]")
    expect(page).to have_content("must be an .srt file")
    expect(user.uploaded_videos.find_by(title: "Bad Captions Clip")).to be_uploading
  end

  # Subtitles picked before the video file ride along with the draft save.
  it "keeps subtitles chosen before the video file was picked" do
    visit account_path
    find(".account__action[aria-label='Upload video']").click
    expect(page).to have_css("dialog.modal[open]")

    within(subtitle_row(0)) do
      attach_file SAMPLE_SRT, make_visible: true
      select "French", from: "video[subtitles_attributes][0][language]"
    end

    fill_in "Title", with: "Early Captions Clip"
    attach_file "Video file", SAMPLE_VIDEO, make_visible: true
    expect(page).to have_content("Finish your upload")

    # Saved with the draft, so the finish step lists it as done.
    expect(page).to have_content("French")
    draft = user.uploaded_videos.find_by(title: "Early Captions Clip")
    expect(draft.subtitles.pluck(:language)).to eq([ "french" ])
  end
end
