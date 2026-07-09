require 'rails_helper'

RSpec.describe "Category browse", type: :request do
  before do
    user = create(:user, password: "password123")
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /genres/:slug" do
    it "browses the movies and series tagged with the genre" do
      genre = Genre.create!(name: "Action")
      Tagging.create!(genre: genre, taggable: create(:movie))
      Tagging.create!(genre: genre, taggable: create(:serie))

      get genre_browse_path(slug: genre.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body.scan('class="poster-card"').size).to eq(2)
    end
  end

  describe "GET /kinds/:kind" do
    it "browses public videos of that kind" do
      create_list(:video, 3, kind: :trailer, visibility: :public)
      get kind_browse_path(kind: "trailer")
      expect(response.body.scan('class="poster-card"').size).to eq(3)
    end

    it "404s an unknown kind" do
      get kind_browse_path(kind: "nope")
      expect(response).to have_http_status(:not_found)
    end
  end
end
