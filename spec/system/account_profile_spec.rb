require 'rails_helper'

RSpec.describe "Account profile", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "renders the background, avatar, action icons, and the four rails" do
    user = create(:user, password: "password123")
    create(:video, uploader: user, kind: :standalone, visibility: :public)
    create(:like, user: user, likeable: create(:video))
    create(:playlist, :with_videos, user: user, videos_count: 2)
    create(:video_view, user: user, video: create(:video))

    sign_in_as(user)
    visit account_path

    expect(page).to have_css(".account__bg")
    expect(page).to have_css(".account__avatar")
    expect(page).to have_css(".account__action", count: 3) # cog + movie + lock (006)

    titles = page.all(".rail__title").map(&:text)
    expect(titles).to include("Recent uploads", "Likes", "Playlists", "History")
  end
end
