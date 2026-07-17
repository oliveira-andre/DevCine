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

  describe "GET /search?q=" do
    it "returns title matches across videos, movies, and series" do
      create(:video, title: "Galaxy Warriors", visibility: :public)
      create(:movie, title: "Galaxy Quest")
      Serie.create!(title: "Galaxy Rangers")
      create(:video, title: "Unrelated Clip", visibility: :public)

      get search_path(q: "galaxy")
      expect(response.body).to include("Galaxy Warriors")
      expect(response.body).to include("Galaxy Quest")
      expect(response.body).to include("Galaxy Rangers")
      expect(response.body).not_to include("Unrelated Clip")
    end

    it "excludes private videos from results" do
      create(:video, title: "Galaxy Secret", visibility: :private, uploader: create(:user))
      get search_path(q: "galaxy")
      expect(response.body).not_to include("Galaxy Secret")
    end

    it "shows an empty state when nothing matches" do
      get search_path(q: "zzzz-no-match")
      expect(response.body).to include("No results for")
    end

    it "treats SQL LIKE wildcards literally" do
      create(:video, title: "Percent Test", visibility: :public)
      get search_path(q: "%")
      expect(response.body).to include("No results for")
    end
  end
end
