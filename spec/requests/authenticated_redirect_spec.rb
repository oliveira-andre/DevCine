require 'rails_helper'

# A signed-in user should not see the sign-in / sign-up pages.
RSpec.describe "Auth pages when already signed in", type: :request do
  let(:member) { create(:user, password: "password123") }

  def sign_in
    post session_path, params: { email_address: member.email_address, password: "password123" }
  end

  context "when signed in" do
    before { sign_in }

    it "redirects GET /session/new to home" do
      get new_session_path
      expect(response).to redirect_to(root_path)
    end

    it "redirects GET /registration/new to home" do
      get new_registration_path
      expect(response).to redirect_to(root_path)
    end
  end

  context "when signed out" do
    it "shows the sign-in page" do
      get new_session_path
      expect(response).to have_http_status(:ok)
    end

    it "shows the sign-up page" do
      get new_registration_path
      expect(response).to have_http_status(:ok)
    end
  end
end
