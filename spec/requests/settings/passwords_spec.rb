require 'rails_helper'

RSpec.describe "Settings::Passwords", type: :request do
  let(:member) { create(:user, password: "password123") }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  describe "GET /settings/password/edit" do
    it "renders the change-password form" do
      get edit_settings_password_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Current password")
    end
  end

  describe "PATCH /settings/password" do
    def change_password(current:, password:, confirmation:)
      patch settings_password_path, params: {
        user: { current_password: current, password: password, password_confirmation: confirmation }
      }
    end

    it "rejects a wrong current password and leaves it unchanged" do
      change_password(current: "wrong", password: "newpass123", confirmation: "newpass123")
      expect(response).to have_http_status(:unprocessable_content)
      expect(member.reload.authenticate("password123")).to be_truthy
    end

    it "rejects a mismatched confirmation" do
      change_password(current: "password123", password: "newpass123", confirmation: "nope")
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "updates the password with the correct current password" do
      change_password(current: "password123", password: "newpass123", confirmation: "newpass123")
      expect(member.reload.authenticate("newpass123")).to be_truthy
    end
  end
end
