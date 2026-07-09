require 'rails_helper'

RSpec.describe "Listings", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  before { sign_in(create(:user, password: "password123")) }

  describe "GET /movies" do
    it "returns a bounded first page of 20 with a next-page frame" do
      create_list(:movie, 25)
      get movies_path
      expect(response).to have_http_status(:ok)
      expect(response.body.scan('class="poster-card"').size).to eq(20)
      expect(response.body).to include('id="movies_page_2"')
    end

    it "renders the next page for ?page=2" do
      create_list(:movie, 25)
      get movies_path(page: 2)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="movies_page_2"')
      expect(response.body.scan('class="poster-card"').size).to eq(5)
    end

    it "does not render a next frame on the last page" do
      create_list(:movie, 10)
      get movies_path
      expect(response.body).not_to include('id="movies_page_2"')
    end

    it "handles a page past the end gracefully (empty, no error)" do
      create_list(:movie, 3)
      get movies_path(page: 99)
      expect(response).to have_http_status(:ok)
      expect(response.body.scan('class="poster-card"').size).to eq(0)
    end
  end

  describe "GET /videos" do
    it "returns a bounded first page of 50 public standalone videos with a next frame" do
      create_list(:video, 55, kind: :standalone, visibility: :public)
      get videos_path
      expect(response.body.scan('class="poster-card"').size).to eq(50)
      expect(response.body).to include('id="videos_page_2"')
    end

    it "excludes non-public videos" do
      create(:video, kind: :standalone, visibility: :public, title: "Shown ABC")
      create(:video, kind: :standalone, visibility: :private, title: "Hidden ABC")
      get videos_path
      expect(response.body).to include("Shown ABC")
      expect(response.body).not_to include("Hidden ABC")
    end
  end

  describe "GET /series" do
    it "returns a bounded first page of 20" do
      create_list(:serie, 25)
      get series_path
      expect(response.body.scan('class="poster-card"').size).to eq(20)
      expect(response.body).to include('id="series_page_2"')
    end
  end

  describe "GET /lives" do
    it "lists public live-kind videos" do
      create_list(:video, 3, kind: :live, visibility: :public)
      create(:video, kind: :standalone, visibility: :public) # excluded
      get lives_path
      expect(response).to have_http_status(:ok)
      expect(response.body.scan('class="poster-card"').size).to eq(3)
    end
  end
end
