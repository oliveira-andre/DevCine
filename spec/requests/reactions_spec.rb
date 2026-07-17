require 'rails_helper'

RSpec.describe "Reactions", type: :request do
  let(:member) { create(:user, password: "password123") }
  let(:video) { create(:video, :with_file, visibility: :public) }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  def react(record, type, kind)
    post reactions_path(type: type, id: record.id, kind: kind), as: :turbo_stream
  end

  it "likes a video and returns a Turbo Stream" do
    expect { react(video, "video", :like) }.to change { video.likes.reaction_like.count }.by(1)
    expect(response.body).to include("reactions_video_#{video.id}")
  end

  it "toggles the reaction off when repeated" do
    react(video, "video", :like)
    expect { react(video, "video", :like) }.to change { video.likes.count }.by(-1)
  end

  it "switches a like to a dislike" do
    react(video, "video", :like)
    react(video, "video", :dislike)
    expect(video.likes.reaction_like.count).to eq(0)
    expect(video.likes.reaction_dislike.count).to eq(1)
  end

  it "removes the video from 'Videos you liked' when switched to dislike" do
    react(video, "video", :like)
    expect(member.liked_playlist.videos).to include(video)
    react(video, "video", :dislike)
    expect(member.liked_playlist.reload.videos).not_to include(video)
  end

  it "reacts to a comment" do
    comment = create(:comment, video: video)
    expect { react(comment, "comment", :like) }.to change { comment.likes.reaction_like.count }.by(1)
  end

  it "404s for an unknown reactable type" do
    react(video, "bogus", :like)
    expect(response).to have_http_status(:not_found)
  end
end
