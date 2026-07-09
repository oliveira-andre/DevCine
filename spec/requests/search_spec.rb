require 'rails_helper'

RSpec.describe "Search", type: :request do
  before do
    user = create(:user, password: "password123")
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /search" do
    it "renders every genre and video-kind category" do
      %w[Action Drama Gaming].each { |name| Genre.create!(name: name) }

      get search_path
      expect(response).to have_http_status(:ok)

      %w[Action Drama Gaming].each { |name| expect(response.body).to include(name) }
      Video.kinds.each_key { |kind| expect(response.body).to include(kind.titleize) }
    end
  end
end
