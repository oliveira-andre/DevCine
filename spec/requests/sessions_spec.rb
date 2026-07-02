require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  describe "GET /session/new" do
    it "renders the sign-in card" do
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Login")
      expect(response.body).to include("Senha")
    end
  end

  describe "POST /session" do
    let(:password) { "password123" }

    it "signs in a valid, non-blocked user and redirects" do
      user = create(:user, password: password)
      post session_path, params: { email_address: user.email_address, password: password }
      expect(response).to redirect_to(root_url)
    end

    it "rejects invalid credentials with a generic alert" do
      user = create(:user, password: password)
      post session_path, params: { email_address: user.email_address, password: "wrong" }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try another email address or password.")
    end

    it "rejects a blocked user without creating a session and without disclosing the block" do
      user = create(:user, :blocked, password: password)
      post session_path, params: { email_address: user.email_address, password: password }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try another email address or password.")
      expect(user.sessions).to be_empty
    end
  end
end
