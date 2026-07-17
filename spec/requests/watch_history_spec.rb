require 'rails_helper'

RSpec.describe "Watch history & liked playlist", type: :request do
  let(:member) { create(:user, password: "password123") }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  it "shows watched videos in the account History rail, linking to the player" do
    video = create(:video, :with_thumbnail, visibility: :public)
    VideoView.record!(member, video)

    get account_path
    expect(response.body).to include(video.title)
    expect(response.body).to include(player_path(video.slug))
  end

  it "shows the auto-created 'Videos you liked' playlist on the account" do
    get account_path
    expect(response.body).to include(User::LIKED_PLAYLIST_TITLE)
  end
end
