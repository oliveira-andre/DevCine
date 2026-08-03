require 'rails_helper'

RSpec.describe "Admin dashboard", type: :request do
  let(:admin) { create(:user, :admin, password: "password123") }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "turns a non-admin away" do
    sign_in_as(create(:user, password: "password123"))

    get admin_dashboard_path

    expect(response).to redirect_to(root_path)
  end

  context "as an admin" do
    before { sign_in_as(admin) }

    it "keeps the summary counts" do
      create_list(:video, 2, visibility: :public)
      create(:playlist)

      get admin_dashboard_path

      expect(response).to have_http_status(:ok)
      %w[Members Videos Movies Playlists].each { |label| expect(response.body).to include(label) }
    end

    it "lists a recent slice of members, videos, movies and playlists" do
      member = create(:user, email_address: "recent.member@example.com")
      create(:video, title: "Recently Added Clip", visibility: :public, uploader: member)
      create(:movie, title: "Recently Added Movie")
      create(:playlist, user: member, title: "Recently Added Mix")

      get admin_dashboard_path

      expect(response.body).to include("Recent members")
      expect(response.body).to include("recent.member@example.com")
      expect(response.body).to include("Recent videos")
      expect(response.body).to include("Recently Added Clip")
      expect(response.body).to include("Recent movies")
      expect(response.body).to include("Recently Added Movie")
      expect(response.body).to include("Recent playlists")
      expect(response.body).to include("Recently Added Mix")
    end

    it "links a member row through to their admin detail page" do
      member = create(:user, email_address: "linked@example.com")

      get admin_dashboard_path

      expect(response.body).to include(admin_user_path(member))
    end

    # The dashboard is a landing page, so it follows the same rule as the user
    # detail rails: nothing non-public surfaces here.
    it "keeps private and restricted titles out of the recent videos table" do
      create(:video, title: "Public Clip", visibility: :public)
      create(:video, title: "Private Clip", visibility: :private)
      create(:video, title: "Restricted Clip", visibility: :restricted, maturity_rating: :A18)

      get admin_dashboard_path

      expect(response.body).to include("Public Clip")
      expect(response.body).not_to include("Private Clip")
      expect(response.body).not_to include("Restricted Clip")
    end

    it "renders with nothing to show" do
      Video.destroy_all
      Playlist.destroy_all

      get admin_dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No public videos yet.")
    end
  end
end
