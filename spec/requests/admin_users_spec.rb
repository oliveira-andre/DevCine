require 'rails_helper'

RSpec.describe "Admin users", type: :request do
  let(:admin) { create(:user, :admin, password: "password123") }
  let(:member) do
    create(:user, password: "password123", email_address: "member@example.com",
                  display_name: "Member One")
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "authorization" do
    it "turns a non-admin away from every action" do
      sign_in_as(member)

      get admin_users_path
      expect(response).to redirect_to(root_path)

      get admin_user_path(member)
      expect(response).to redirect_to(root_path)

      patch admin_user_path(member), params: { user: { display_name: "Hacked" } }
      expect(response).to redirect_to(root_path)
      expect(member.reload.display_name).to eq("Member One")
    end
  end

  context "as an admin" do
    before { sign_in_as(admin) }

    describe "GET /admin/users" do
      it "lists members and finds one by email" do
        member
        other = create(:user, email_address: "someone.else@example.com")

        get admin_users_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("member@example.com")

        get admin_users_path(q: "member@")
        expect(response.body).to include("member@example.com")
        expect(response.body).not_to include(other.email_address)
      end

      it "also matches on display name" do
        member

        get admin_users_path(q: "Member One")
        expect(response.body).to include("member@example.com")
      end
    end

    describe "GET /admin/users/:id" do
      it "shows the member's details and recent activity from each area" do
        video = create(:video, title: "Commented Film", visibility: :public)
        create(:comment, user: member, video: video, body: "A memorable remark")
        create(:playlist, user: member, title: "Road Trip Mix")
        create(:like, user: member, likeable: create(:video, title: "Liked Film"))
        create(:video, uploader: member, title: "Uploaded Film")

        get admin_user_path(member)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("member@example.com")
        expect(response.body).to include("A memorable remark")
        expect(response.body).to include("Road Trip Mix")
        expect(response.body).to include("Liked Film")
        expect(response.body).to include("Uploaded Film")
      end

      it "links to the see-all page for each area that has content" do
        create(:comment, user: member)

        get admin_user_path(member)

        expect(response.body).to include(comments_admin_user_path(member))
      end

      # The recent rails are a glance at the member, so they stay public-only —
      # private and restricted titles live behind the PIN on the see-all pages.
      it "keeps private and restricted titles out of the recent rails" do
        create(:video, uploader: member, title: "Public Upload", visibility: :public)
        create(:video, uploader: member, title: "Secret Upload", visibility: :private)
        create(:video, uploader: member, title: "Adult Upload", visibility: :restricted,
                       maturity_rating: :A18)
        create(:like, user: member,
                      likeable: create(:video, title: "Secret Like", visibility: :private))

        get admin_user_path(member)

        expect(response.body).to include("Public Upload")
        expect(response.body).not_to include("Secret Upload")
        expect(response.body).not_to include("Adult Upload")
        expect(response.body).not_to include("Secret Like")
      end
    end

    describe "the see-all pages" do
      it "paginates each area" do
        create(:comment, user: member, body: "Paged remark")
        create(:playlist, user: member, title: "Paged Mix")
        create(:like, user: member, likeable: create(:video, title: "Paged Like"))
        create(:video, uploader: member, title: "Paged Upload")

        get comments_admin_user_path(member)
        expect(response.body).to include("Paged remark")

        get playlists_admin_user_path(member)
        expect(response.body).to include("Paged Mix")

        get likes_admin_user_path(member)
        expect(response.body).to include("Paged Like")

        get uploads_admin_user_path(member)
        expect(response.body).to include("Paged Upload")
      end

      it "shows only the requested member's activity" do
        create(:comment, user: member, body: "Mine")
        create(:comment, user: create(:user), body: "Somebody else's")

        get comments_admin_user_path(member)

        expect(response.body).to include("Mine")
        expect(response.body).not_to include("Somebody else&#39;s")
      end
    end

    describe "the PIN gate on the video see-all pages" do
      let!(:public_upload) { create(:video, uploader: member, title: "Open Upload", visibility: :public) }
      let!(:private_upload) { create(:video, uploader: member, title: "Hidden Upload", visibility: :private) }
      let!(:restricted_upload) do
        create(:video, uploader: member, title: "Adult Upload", visibility: :restricted,
                       maturity_rating: :A18)
      end

      # Mirrors spec/requests/restricted_content_spec.rb: unlocking mints the
      # session half of the token; the client half rides on every later request.
      def unlock_headers
        post unlock_settings_pin_path, params: { pin: "1234" }, as: :turbo_stream
        { "X-Pin-Unlock" => session[:pin_unlock_token] }
      end

      it "hides private and restricted titles while locked" do
        get uploads_admin_user_path(member)

        expect(response.body).to include("Open Upload")
        expect(response.body).not_to include("Hidden Upload")
        expect(response.body).not_to include("Adult Upload")
        expect(response.body).to include("Private and restricted titles are hidden")
      end

      it "reveals them once the admin unlocks with their PIN" do
        admin.update!(pin: "1234", pin_confirmation: "1234")

        get uploads_admin_user_path(member), headers: unlock_headers

        expect(response.body).to include("Open Upload")
        expect(response.body).to include("Hidden Upload")
        expect(response.body).to include("Adult Upload")
        expect(response.body).not_to include("Private and restricted titles are hidden")
      end

      it "gates the likes page the same way" do
        create(:like, user: member, likeable: private_upload)
        admin.update!(pin: "1234", pin_confirmation: "1234")

        get likes_admin_user_path(member)
        expect(response.body).not_to include("Hidden Upload")

        get likes_admin_user_path(member), headers: unlock_headers
        expect(response.body).to include("Hidden Upload")
      end

      # Liking a video files it into the member's "Videos you liked" playlist,
      # so an ungated playlist panel would republish every private title.
      it "does not leak a hidden title through a playlist's member list" do
        create(:like, user: member, likeable: private_upload)

        get playlists_admin_user_path(member)

        expect(response.body).not_to include("Hidden Upload")
        expect(response.body).to include("hidden until you unlock")
      end

      it "does not leak a hidden title through the video a comment sits on" do
        create(:comment, user: member, video: private_upload, body: "Commented here")

        get comments_admin_user_path(member)

        expect(response.body).to include("Commented here")
        expect(response.body).not_to include("Hidden Upload")
        expect(response.body).to include("Hidden title")
      end

      # With no PIN there is no way to mint a token, so the titles are
      # unreachable rather than merely hidden.
      it "cannot reveal them at all when the admin has no PIN" do
        expect(admin.pin?).to be(false)

        post unlock_settings_pin_path, params: { pin: "1234" }, as: :turbo_stream
        expect(session[:pin_unlock_token]).to be_blank

        get uploads_admin_user_path(member), headers: { "X-Pin-Unlock" => "forged-token" }

        expect(response.body).not_to include("Hidden Upload")
        expect(response.body).to include("Set a PIN")
      end
    end

    describe "PATCH /admin/users/:id" do
      it "updates the profile fields a member could change themselves" do
        patch admin_user_path(member), params: { user: { display_name: "Renamed" } }

        expect(member.reload.display_name).to eq("Renamed")
      end

      it "changes email and role — things only an admin can do" do
        patch admin_user_path(member),
              params: { user: { email_address: "moved@example.com", role: "blocked" } }

        member.reload
        expect(member.email_address).to eq("moved@example.com")
        expect(member).to be_blocked
      end

      it "sets a new password without needing the current one" do
        patch admin_user_path(member),
              params: { user: { password: "brand-new-pw", password_confirmation: "brand-new-pw" } }

        expect(member.reload.authenticate("brand-new-pw")).to be_truthy
      end

      it "leaves the password alone when the field is blank" do
        digest = member.password_digest

        patch admin_user_path(member),
              params: { user: { display_name: "Still Me", password: "", password_confirmation: "" } }

        member.reload
        expect(member.display_name).to eq("Still Me")
        expect(member.password_digest).to eq(digest)
        expect(member.authenticate("password123")).to be_truthy
      end

      it "rejects a mismatched password confirmation" do
        patch admin_user_path(member),
              params: { user: { password: "one-password", password_confirmation: "other-password" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(member.reload.authenticate("password123")).to be_truthy
      end

      it "rejects an email that belongs to somebody else" do
        create(:user, email_address: "taken@example.com")

        patch admin_user_path(member), params: { user: { email_address: "taken@example.com" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(member.reload.email_address).to eq("member@example.com")
      end

      # Losing your own admin rights would leave no way back through the UI.
      it "ignores an admin's attempt to change their own role" do
        patch admin_user_path(admin), params: { user: { role: "blocked" } }

        expect(admin.reload).to be_admin
      end

      it "still lets an admin edit their own other fields" do
        patch admin_user_path(admin), params: { user: { display_name: "The Boss" } }

        expect(admin.reload.display_name).to eq("The Boss")
        expect(admin).to be_admin
      end
    end
  end
end
