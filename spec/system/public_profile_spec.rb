require 'rails_helper'

RSpec.describe "Public profile", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "shows a read-only public profile: no actions, public-only content, no History" do
    viewer = create(:user, password: "password123")
    owner = create(:user, display_name: "Owner Person")
    create(:video, uploader: owner, kind: :standalone, visibility: :public, title: "Owner Public Vid")
    create(:video, uploader: owner, kind: :standalone, visibility: :private, title: "Owner Private Vid")
    create(:video_view, user: owner, video: create(:video))

    sign_in_as(viewer)
    visit public_account_path(slug: owner.handle)

    expect(page).to have_content("Owner Person")
    expect(page).to have_no_css(".account__action") # no owner actions
    expect(page).to have_content("Owner Public Vid")
    expect(page).to have_no_content("Owner Private Vid")
    expect(page.all(".rail__title").map(&:text)).not_to include("History")
  end
end
