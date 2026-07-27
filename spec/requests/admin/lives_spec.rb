require 'rails_helper'

RSpec.describe "Admin::Lives", type: :request do
  let(:admin) { create(:user, :admin, password: "password123") }
  let(:member) { create(:user, password: "password123") }
  let(:embed) { "https://www.youtube.com/embed/O8bnDdWsk8Q" }
  let(:ts) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "access control" do
    it "redirects a non-admin away from the lives page and mutations" do
      sign_in(member)
      get admin_lives_path
      expect(response).to redirect_to(root_path)
      expect { post admin_lives_path, params: { video: { title: "X", live_embed_url: embed } } }
        .not_to change(Video, :count)
    end
  end

  context "as an admin" do
    before { sign_in(admin) }

    describe "GET /admin/lives" do
      it "lists lives and renders the sidebar + Add" do
        create(:video, :live, title: "Opening Night")
        get admin_lives_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Opening Night")
        expect(response.body).to include(new_admin_life_path)
      end

      it "filters by title with q" do
        create(:video, :live, title: "Football Final")
        create(:video, :live, title: "Cooking Show")
        get admin_lives_path(q: "foot")
        expect(response.body).to include("Football Final")
        expect(response.body).not_to include("Cooking Show")
      end
    end

    describe "GET /admin/lives/new" do
      it "renders the modal with title + embed fields" do
        get new_admin_life_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("video[title]").and include("video[live_embed_url]")
      end
    end

    describe "POST /admin/lives" do
      it "creates a public live and prepends the row + closes the modal" do
        expect {
          post admin_lives_path, params: { video: { title: "Big Game", live_embed_url: embed } }, headers: ts
        }.to change(Video.live, :count).by(1)
        live = Video.live.order(:created_at).last
        expect(live.visibility).to eq("public")
        expect(response.body).to include('action="prepend" target="admin_lives"')
        expect(response.body).to include('action="update" target="modal"')
        expect(response.body).to include("Big Game")
      end

      it "rejects a blank title or non-https URL (422), creates nothing" do
        expect {
          post admin_lives_path, params: { video: { title: "", live_embed_url: embed } }, headers: ts
        }.not_to change(Video, :count)
        expect(response).to have_http_status(:unprocessable_content)

        expect {
          post admin_lives_path, params: { video: { title: "Bad", live_embed_url: "http://x/e" } }, headers: ts
        }.not_to change(Video, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "GET /admin/lives/:id/edit" do
      it "renders the modal pre-filled" do
        live = create(:video, :live, title: "Pre Fill")
        get edit_admin_life_path(live)
        expect(response.body).to include("Pre Fill").and include(live.live_embed_url)
      end
    end

    describe "PATCH /admin/lives/:id" do
      it "updates and replaces the row" do
        live = create(:video, :live, title: "Old Title")
        patch admin_life_path(live), params: { video: { title: "New Title", live_embed_url: embed } }, headers: ts
        expect(live.reload.title).to eq("New Title")
        expect(response.body).to include(%(target="admin_live_row_#{live.id}"))
      end

      it "422s on invalid input" do
        live = create(:video, :live)
        patch admin_life_path(live), params: { video: { title: "" } }, headers: ts
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    describe "DELETE /admin/lives/:id" do
      it "destroys the live and removes the row" do
        live = create(:video, :live)
        expect { delete admin_life_path(live), headers: ts }.to change(Video, :count).by(-1)
        expect(response.body).to include(%(target="admin_live_row_#{live.id}"))
      end
    end
  end
end
