require 'rails_helper'

# Feature 011: catalog filter (genre) + sort (ordering) across listings.
RSpec.describe "Catalog filters & sorting", type: :request do
  let(:member) { create(:user, password: "password123") }
  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  # Deterministic catalog: titles + timestamps chosen so orderings are distinct.
  let!(:zebra) { movie("Zebra Movie", 3.hours.ago) }   # newest, last alphabetically
  let!(:apple) { movie("Apple Movie", 2.hours.ago) }
  let!(:mango) { movie("Mango Movie", 1.hour.ago) }     # oldest of the three? no — see below

  def movie(title, created)
    v = create(:video, :with_thumbnail, kind: :feature, visibility: :public, created_at: created)
    create(:movie, title: title, video: v, created_at: created)
  end

  # Dedupe: a poster card may render the title more than once (text + aria).
  def titles(body) = body.scan(/(Zebra|Apple|Mango) Movie/).flatten.map { |m| "#{m} Movie" }.uniq

  before do
    Ordering.find_or_create_by!(label: "Most older") { |o| o.field = "created_at"; o.direction = "asc"; o.position = 1 }
    Ordering.find_or_create_by!(label: "A-Z") { |o| o.field = "title"; o.direction = "asc"; o.position = 2 }
    Ordering.find_or_create_by!(label: "Z-A") { |o| o.field = "title"; o.direction = "desc"; o.position = 3 }
    Ordering.where(default: true).update_all(default: false)
    Ordering.bump_version(Ordering::CACHE_SCOPE)
  end

  describe "US2 — ordering" do
    it "defaults to most recent (newest first)" do
      get movies_path
      # created: zebra(3h) apple(2h) mango(1h) → newest first = mango, apple, zebra
      expect(titles(response.body).first(3)).to eq(["Mango Movie", "Apple Movie", "Zebra Movie"])
    end

    it "sorts A-Z by title" do
      get movies_path(sort: "a-z")
      expect(titles(response.body).first(3)).to eq(["Apple Movie", "Mango Movie", "Zebra Movie"])
    end

    it "sorts Z-A by title" do
      get movies_path(sort: "z-a")
      expect(titles(response.body).first(3)).to eq(["Zebra Movie", "Mango Movie", "Apple Movie"])
    end

    it "sorts oldest first" do
      get movies_path(sort: "most-older")
      expect(titles(response.body).first(3)).to eq(["Zebra Movie", "Apple Movie", "Mango Movie"])
    end

    it "falls back to most recent for an unknown sort" do
      get movies_path(sort: "bogus")
      expect(titles(response.body).first(3)).to eq(["Mango Movie", "Apple Movie", "Zebra Movie"])
    end

    it "renders the ordering pill on non-genre listings (videos)" do
      get videos_path
      expect(response.body).to include("catalog-controls__sort")
      expect(response.body).not_to include("catalog-controls__genres")
    end

    it "applies ordering on series, videos, and lives too" do
      get series_index_path(sort: "a-z"); expect(response).to have_http_status(:ok)
      get videos_path(sort: "z-a"); expect(response).to have_http_status(:ok)
      get lives_path(sort: "most-older"); expect(response).to have_http_status(:ok)
    end
  end

  describe "US1 — genre filter (movies/series only)" do
    let!(:action) { Genre.find_or_create_by!(name: "Action") }
    before { create(:tagging, genre: action, taggable: apple) }

    it "filters movies to the selected genre" do
      get movies_path(genre: action.slug)
      names = titles(response.body)
      expect(names).to include("Apple Movie")
      expect(names).not_to include("Zebra Movie")
    end

    it "shows the genre pill row on movies" do
      get movies_path
      expect(response.body).to include("catalog-controls__genres")
      expect(response.body).to include("Action")
    end

    it "ignores an unknown genre (shows all)" do
      get movies_path(genre: "does-not-exist")
      expect(titles(response.body)).to include("Zebra Movie", "Apple Movie", "Mango Movie")
    end

    it "composes genre + sort" do
      create(:tagging, genre: action, taggable: zebra)
      get movies_path(genre: action.slug, sort: "a-z")
      names = titles(response.body).select { |t| ["Apple Movie", "Zebra Movie"].include?(t) }
      expect(names).to eq(["Apple Movie", "Zebra Movie"])
    end

    it "does not render a genre row on videos/lives" do
      get lives_path
      expect(response.body).not_to include("catalog-controls__genres")
    end
  end

  describe "US3 — default resolution" do
    it "opens in the default record's order when one is marked default" do
      Ordering.find_by(slug: "a-z").update!(default: true)
      Ordering.bump_version(Ordering::CACHE_SCOPE)
      get movies_path
      expect(titles(response.body).first(3)).to eq(["Apple Movie", "Mango Movie", "Zebra Movie"])
    end

    it "still renders the ordering pill with an empty orderings table" do
      Ordering.delete_all
      Ordering.bump_version(Ordering::CACHE_SCOPE)
      get movies_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("catalog-controls__sort")
      expect(titles(response.body).first(3)).to eq(["Mango Movie", "Apple Movie", "Zebra Movie"])
    end
  end

  describe "visibility" do
    it "never shows a private movie under any filter/sort" do
      hidden_v = create(:video, :with_thumbnail, kind: :feature, visibility: :private, uploader: create(:user))
      create(:movie, title: "Hidden Movie", video: hidden_v)
      get movies_path(sort: "a-z")
      expect(response.body).not_to include("Hidden Movie")
    end
  end
end
