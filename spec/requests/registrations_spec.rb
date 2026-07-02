require 'rails_helper'

RSpec.describe "Registrations", type: :request do
  describe "GET /registration/new" do
    it "renders the sign-up card" do
      get new_registration_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Create account")
    end
  end

  describe "POST /registration" do
    let(:valid_params) do
      { user: { email_address: "new.person@example.com",
                password: "password123", password_confirmation: "password123" } }
    end

    it "creates a user with the role 'user' and starts a session" do
      expect {
        post registration_path, params: valid_params
      }.to change(User, :count).by(1)

      user = User.find_by(email_address: "new.person@example.com")
      expect(user.role).to eq("user")
      expect(response).to redirect_to(root_url)
    end

    it "always forces role 'user' even if a role is submitted" do
      post registration_path, params: valid_params.deep_merge(user: { role: "admin" })
      expect(User.find_by(email_address: "new.person@example.com").role).to eq("user")
    end

    it "rejects a mismatched password confirmation server-side" do
      expect {
        post registration_path, params: { user: { email_address: "x@example.com",
              password: "password123", password_confirmation: "nope" } }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a duplicate email" do
      create(:user, email_address: "taken@example.com")
      expect {
        post registration_path, params: { user: { email_address: "taken@example.com",
              password: "password123", password_confirmation: "password123" } }
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
