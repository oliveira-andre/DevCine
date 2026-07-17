require 'rails_helper'

RSpec.describe "Passwords", type: :request do
  let(:member) { create(:user, password: "password123") }

  describe "GET /passwords/new" do
    it "renders the styled forgot-password page without auth" do
      get new_password_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("auth__card")
      expect(response.body).to include("Email reset instructions")
    end
  end

  describe "POST /passwords" do
    it "sends reset instructions for a known email" do
      expect {
        post passwords_path, params: { email_address: member.email_address }
      }.to have_enqueued_mail(PasswordsMailer, :reset)
      expect(response).to redirect_to(new_session_path)
    end

    it "does not disclose whether the email exists" do
      post passwords_path, params: { email_address: "nobody@example.com" }
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "PUT /passwords/:token" do
    it "resets the password with a valid token" do
      token = member.password_reset_token
      put password_path(token), params: { password: "newpassword1", password_confirmation: "newpassword1" }
      expect(response).to redirect_to(new_session_path)
      expect(member.reload.authenticate("newpassword1")).to be_truthy
    end

    it "rejects an invalid token" do
      put password_path("bogus-token"), params: { password: "x", password_confirmation: "x" }
      expect(response).to redirect_to(new_password_path)
    end
  end

  describe "sign-in page" do
    it "links to the forgot-password flow and shows notices" do
      get new_session_path
      expect(response.body).to include(new_password_path)
    end
  end
end
