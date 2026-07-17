require 'rails_helper'

RSpec.describe "Admin::Dashboard", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /admin/dashboard" do
    it "renders for an admin" do
      sign_in(create(:user, :admin, password: "password123"))
      get admin_dashboard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Admin dashboard")
    end

    it "redirects a non-admin member to the home screen" do
      sign_in(create(:user, password: "password123"))
      get admin_dashboard_path
      expect(response).to redirect_to(root_path)
    end

    it "redirects an unauthenticated visitor to sign in" do
      get admin_dashboard_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "drawer navigation link" do
    it "shows the Dashboard link for admins" do
      sign_in(create(:user, :admin, password: "password123"))
      get root_path
      expect(response.body).to include(admin_dashboard_path)
    end

    it "hides the Dashboard link for regular members" do
      sign_in(create(:user, password: "password123"))
      get root_path
      expect(response.body).not_to include(admin_dashboard_path)
    end
  end
end
