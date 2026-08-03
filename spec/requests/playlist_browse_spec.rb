require 'rails_helper'

RSpec.describe "Playlist browse and search", type: :request do
  let(:member) { create(:user, password: "password123") }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  describe "GET /playlists" do
    it "lists public playlists with their owner" do
      owner = create(:user, display_name: "Ada Lovelace")
      create(:playlist, user: owner, title: "Road Trip", visibility: :public)

      get playlists_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Road Trip")
      expect(response.body).to include("Ada Lovelace")
    end

    # Unlisted means reachable by link but never listed — browse and search must
    # both respect that, and private is nobody else's business.
    it "leaves out unlisted and private playlists, including the viewer's own" do
      create(:playlist, title: "Public List", visibility: :public)
      create(:playlist, title: "Unlisted List", visibility: :unlisted)
      create(:playlist, user: member, title: "My Private List", visibility: :private)

      get playlists_path

      expect(response.body).to include("Public List")
      expect(response.body).not_to include("Unlisted List")
      expect(response.body).not_to include("My Private List")
    end

    it "filters by title" do
      create(:playlist, title: "Jazz Essentials", visibility: :public)
      create(:playlist, title: "Rock Anthems", visibility: :public)

      get playlists_path(q: "jazz")

      expect(response.body).to include("Jazz Essentials")
      expect(response.body).not_to include("Rock Anthems")
    end

    it "says so when nothing matches" do
      get playlists_path(q: "nothing-like-this")

      expect(response.body).to include("No playlists match")
    end
  end

  describe "GET /search" do
    it "returns public playlists whose title matches" do
      create(:playlist, title: "Galaxy Mix", visibility: :public)
      create(:video, title: "Galaxy Warriors", visibility: :public)

      get search_path(q: "galaxy")

      expect(response.body).to include("Playlists")
      expect(response.body).to include("Galaxy Mix")
      expect(response.body).to include("Galaxy Warriors")
    end

    it "does not surface unlisted or private playlists" do
      create(:playlist, title: "Galaxy Unlisted", visibility: :unlisted)
      create(:playlist, user: member, title: "Galaxy Private", visibility: :private)

      get search_path(q: "galaxy")

      expect(response.body).not_to include("Galaxy Unlisted")
      expect(response.body).not_to include("Galaxy Private")
    end

    it "still reports no results when only a hidden playlist matches" do
      create(:playlist, title: "Galaxy Unlisted", visibility: :unlisted)

      get search_path(q: "galaxy")

      expect(response.body).to include("No results for")
    end
  end
end
