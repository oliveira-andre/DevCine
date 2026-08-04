require 'rails_helper'

RSpec.describe "Admin video management", type: :system do
  let(:admin) { create(:user, :admin, password: "password123") }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(admin) }

  it "reaches videos from the nav and lists them" do
    create(:video, :with_thumbnail, title: "A Managed Clip", visibility: :public)
    visit admin_dashboard_path

    find(".admin-header__menu").click
    within(".admin-nav") { click_link "Videos" }

    expect(page).to have_current_path(admin_videos_path)
    expect(page).to have_content("A Managed Clip")
  end

  it "filters the list by kind" do
    create(:video, :with_thumbnail, title: "The Feature", kind: :feature, visibility: :public)
    create(:video, :with_thumbnail, title: "The Standalone", kind: :standalone, visibility: :public)
    visit admin_videos_path

    select "Feature", from: "kind"

    expect(page).to have_content("The Feature")
    expect(page).to have_no_content("The Standalone")
  end

  it "opens a video's detail page" do
    video = create(:video, :with_thumbnail, :with_file, title: "Detail Clip", visibility: :public)
    visit admin_videos_path

    within("#admin_video_row_#{video.id}") { find(".admin-live__action[aria-label='View Detail Clip']").click }

    expect(page).to have_current_path(admin_video_path(video))
    expect(page).to have_content("Detail Clip")
    expect(page).to have_content("Subtitles")
  end

  it "edits a video's metadata through the modal" do
    video = create(:video, :with_thumbnail, :with_file, title: "Before", visibility: :public)
    visit admin_video_path(video)

    click_link "Edit"
    expect(page).to have_css("dialog.modal[open]")
    fill_in "Title", with: "After"
    click_button "Save"

    expect(page).to have_no_css("dialog.modal[open]")
    within("#admin_video_detail") { expect(page).to have_content("After") }
    expect(video.reload.title).to eq("After")
  end

  it "deletes a video from the list" do
    video = create(:video, :with_thumbnail, title: "Doomed Clip", visibility: :public)
    visit admin_videos_path

    accept_confirm do
      within("#admin_video_row_#{video.id}") { find(".admin-live__action--danger").click }
    end

    expect(page).to have_no_content("Doomed Clip")
    expect(Video.exists?(video.id)).to be(false)
  end

  it "deletes from the detail page and returns to the list" do
    video = create(:video, :with_thumbnail, :with_file, title: "Detail Doom", visibility: :public)
    visit admin_video_path(video)

    accept_confirm { click_button "Delete" }

    expect(page).to have_current_path(admin_videos_path)
    expect(Video.exists?(video.id)).to be(false)
  end
end
