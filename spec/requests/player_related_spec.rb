require 'rails_helper'

RSpec.describe "Player related", type: :request do
  let(:member) { create(:user, password: "password123") }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  describe "GET /playing/:slug/related (lazy frame)" do
    it "lists recent public videos of the same kind, excluding the current one" do
      current = create(:video, :with_file, kind: :standalone, visibility: :public, title: "Current Clip")
      same = create(:video, :with_thumbnail, kind: :standalone, visibility: :public, title: "Same Kind Clip")
      other = create(:video, kind: :feature, visibility: :public, title: "Other Kind Film")

      get player_related_path(current.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("related") # turbo frame id
      expect(response.body).to include(same.title)
      expect(response.body).not_to include(other.title)
      expect(response.body).not_to include(current.title)
    end

    it "shows an empty state when there are no same-kind videos" do
      current = create(:video, :with_file, kind: :tutorial, visibility: :public)
      get player_related_path(current.slug)
      expect(response.body).to include("No related videos yet")
    end
  end
end
