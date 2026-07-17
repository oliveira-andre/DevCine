require 'rails_helper'

RSpec.describe "Comments", type: :request do
  let(:member) { create(:user, password: "password123") }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  describe "GET /playing/:slug/comments (lazy frame)" do
    it "renders the comments frame with existing comments" do
      video = create(:video, :with_file, visibility: :public)
      create(:comment, video: video, body: "First comment here")

      get player_comments_path(video.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("First comment here")
      expect(response.body).to include("comments_page_1")
    end

    it "shows 'No comments yet' when empty" do
      video = create(:video, :with_file, visibility: :public)
      get player_comments_path(video.slug)
      expect(response.body).to include("No comments yet")
    end

    it "renders the thread without per-comment N+1 queries" do
      video = create(:video, :with_file, visibility: :public)
      create_list(:comment, 8, video: video).each do |comment|
        create(:comment, video: video, parent_id: comment.id)
        create(:like, user: create(:user), likeable: comment)
      end

      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        get player_comments_path(video.slug)
      end
      # 8 top-level + 8 replies + reactions used to cost 100+ queries; the
      # eager-loaded thread stays flat (~20 incl. the policy slug/record gate).
      expect(queries).to be < 25
    end
  end

  describe "POST /playing/:slug/comments" do
    it "creates a comment and prepends it via Turbo Stream" do
      video = create(:video, :with_file, visibility: :public)
      expect {
        post player_comments_path(video.slug), params: { comment: { body: "Great video" } }, as: :turbo_stream
      }.to change(video.comments, :count).by(1)
      expect(response.body).to include("Great video")
    end

    it "rejects a blank comment with 422" do
      video = create(:video, :with_file, visibility: :public)
      post player_comments_path(video.slug), params: { comment: { body: "" } }, as: :turbo_stream
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "creates a reply to a comment and appends it under the parent" do
      video = create(:video, :with_file, visibility: :public)
      parent = create(:comment, video: video)
      expect {
        post player_comments_path(video.slug),
             params: { comment: { body: "A thoughtful reply", parent_id: parent.id } }, as: :turbo_stream
      }.to change { parent.replies.count }.by(1)
      expect(response.body).to include("replies_#{parent.id}")
    end
  end
end
