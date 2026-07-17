require 'rails_helper'

RSpec.describe "Home banner", type: :request do
  let(:member) { create(:user, password: "password123") }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  it "links the hero banner to the player for the featured movie's video" do
    video = create(:video, :with_thumbnail, visibility: :public)
    create(:movie, :with_backdrop_key, video: video)

    get root_path
    expect(response.body).to include(player_path(video.slug))
  end
end
