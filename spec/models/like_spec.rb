require 'rails_helper'

RSpec.describe Like, type: :model do
  let(:user) { create(:user) }
  let(:video) { create(:video) }

  it "appends the video to the user's 'Videos you liked' playlist on create" do
    create(:like, user: user, likeable: video)
    expect(user.liked_playlist.videos).to include(video)
  end

  it "removes the video from the playlist on destroy" do
    like = create(:like, user: user, likeable: video)
    like.destroy
    expect(user.liked_playlist.videos).not_to include(video)
  end

  it "does not add non-video likeables to the playlist" do
    create(:like, user: user, likeable: create(:movie))
    expect(user.liked_playlist.playlist_items).to be_empty
  end
end
