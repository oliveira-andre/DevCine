require 'rails_helper'

RSpec.describe "Admin comments", type: :request do
  let(:admin) { create(:user, :admin, password: "password123") }
  let(:member) { create(:user, display_name: "Ada", email_address: "ada@example.com") }
  let(:video) { create(:video, title: "Commented Film", visibility: :public) }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "turns a non-admin away" do
    sign_in_as(create(:user, password: "password123"))

    get admin_comments_path
    expect(response).to redirect_to(root_path)
  end

  context "as an admin" do
    before { sign_in_as(admin) }

    describe "GET /admin/comments" do
      it "lists comments with their author and video" do
        create(:comment, user: member, video: video, body: "A memorable remark")

        get admin_comments_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("A memorable remark")
        expect(response.body).to include("Ada")
        expect(response.body).to include("Commented Film")
      end

      it "searches the body" do
        create(:comment, user: member, video: video, body: "findable haystack")
        create(:comment, user: member, video: video, body: "unrelated content")

        get admin_comments_path(q: "haystack")

        expect(response.body).to include("findable haystack")
        expect(response.body).not_to include("unrelated content")
      end

      it "searches by commenter email or name" do
        create(:comment, user: member, video: video, body: "by ada")
        create(:comment, user: create(:user, email_address: "zoe@example.com"), video: video, body: "by zoe")

        get admin_comments_path(q: "ada@example.com")
        expect(response.body).to include("by ada")
        expect(response.body).not_to include("by zoe")
      end

      it "filters threads vs replies" do
        thread = create(:comment, user: member, video: video, body: "top level thread")
        create(:comment, user: member, video: video, body: "a nested reply", parent: thread)

        get admin_comments_path(type: "threads")
        expect(response.body).to include("top level thread")
        expect(response.body).not_to include("a nested reply")

        get admin_comments_path(type: "replies")
        expect(response.body).to include("a nested reply")
        expect(response.body).not_to include("top level thread")
      end

      it "filters to one video's comments" do
        other = create(:video, title: "Other Film", visibility: :public)
        create(:comment, user: member, video: video, body: "on this film")
        create(:comment, user: member, video: other, body: "on the other film")

        get admin_comments_path(video_id: video.id)

        expect(response.body).to include("on this film")
        expect(response.body).not_to include("on the other film")
      end

      it "orders oldest-first when asked" do
        create(:comment, user: member, video: video, body: "older one", created_at: 2.days.ago)
        create(:comment, user: member, video: video, body: "newer one", created_at: 1.hour.ago)

        get admin_comments_path(sort: "oldest")

        expect(response.body.index("older one")).to be < response.body.index("newer one")
      end
    end

    describe "GET /admin/comments/:id" do
      it "shows the comment, its video, and its replies" do
        thread = create(:comment, user: member, video: video, body: "the parent remark")
        create(:comment, user: member, video: video, body: "the child reply", parent: thread)

        get admin_comment_path(thread)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("the parent remark")
        expect(response.body).to include("the child reply")
        expect(response.body).to include("Commented Film")
      end

      # A comment on a restricted title must not leak that title while locked.
      it "masks the video title when the admin is not cleared for it" do
        restricted = create(:video, title: "Adults Only Title", visibility: :restricted, maturity_rating: :A18)
        comment = create(:comment, user: member, video: restricted, body: "commented on restricted")

        get admin_comment_path(comment)

        expect(response.body).to include("commented on restricted")
        expect(response.body).not_to include("Adults Only Title")
        expect(response.body).to include("Hidden title")
      end
    end

    describe "DELETE /admin/comments/:id" do
      it "deletes a comment and cascades to its replies" do
        thread = create(:comment, user: member, video: video, body: "doomed thread")
        reply = create(:comment, user: member, video: video, body: "doomed reply", parent: thread)

        expect {
          delete admin_comment_path(thread)
        }.to change(Comment, :count).by(-2)

        expect(Comment.exists?(reply.id)).to be(false)
      end

      it "removes just the row from the list" do
        comment = create(:comment, user: member, video: video, body: "list delete")

        delete admin_comment_path(comment)

        expect(response.body).to include("admin_comment_row_#{comment.id}")
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "redirects to the list when deleted from the detail page" do
        comment = create(:comment, user: member, video: video, body: "detail delete")

        delete admin_comment_path(comment, back_to_index: true)

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(admin_comments_path)
      end
    end
  end
end
