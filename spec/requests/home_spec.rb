require 'rails_helper'

RSpec.describe "Home", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /" do
    it "redirects an unauthenticated visitor to sign in" do
      get root_path
      expect(response).to redirect_to(new_session_path)
    end

    it "renders for an authenticated member" do
      sign_in(create(:user, password: "password123"))
      get root_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET / content" do
    let(:member) { create(:user, password: "password123") }

    before do
      create_list(:movie, 5)
      create_list(:video, 3, kind: :standalone)
      create_list(:serie, 2)
      sign_in(member)
    end

    it "shows the four rails in the required order" do
      get root_path
      body = response.body

      expect(body).to include("Recently added videos")
      expect(body).to include("Recently added movies")
      expect(body).to include("Recently added series")

      expect(body.index("Recently added videos")).to be < body.index("Recently added movies")
      expect(body.index("Recently added movies")).to be < body.index("Recently added series")
    end

    it "renders a hero of at most four movies" do
      get root_path
      expect(response.body.scan("hero__slide").size).to eq(4)
    end

    it "shows the Last watched rail only when the member has history" do
      get root_path
      expect(response.body).not_to include("Last watched")

      watched = create(:video, kind: :standalone)
      create(:watch_progress, user: member, video: watched)
      get root_path
      expect(response.body).to include("Last watched")
    end
  end

  describe "Last watched videos / movies / series rails" do
    let(:member) { create(:user, password: "password123") }
    let(:serie) { create(:serie, title: "Serie Kappa") }
    let(:season) { create(:season, serie: serie) }

    def watch(video, at: Time.current)
      create(:watch_progress, user: member, video: video, updated_at: at)
    end

    def watch_episode(title, at: Time.current)
      video = create(:video, kind: :episode, title: title)
      create(:episode, season: season, video: video)
      watch(video, at: at)
    end

    # Card titles inside the rail headed `title` ([] when the rail is absent).
    def rail_cards(title)
      rail = Nokogiri::HTML(response.body).css("section.rail")
                     .find { |section| section.at_css(".rail__title").text == title }
      rail ? rail.css(".poster-card__title").map(&:text) : []
    end

    def rail_titles
      Nokogiri::HTML(response.body).css(".rail__title").map(&:text)
    end

    before { sign_in(member) }

    it "places the three rails after Last watched and before Recently added videos" do
      watch(create(:video, kind: :standalone))
      watch(create(:movie).video)
      watch_episode("Pilot")

      get root_path
      expect(rail_titles.first(5)).to eq([
        "Last watched", "Last watched videos", "Last watched movies",
        "Last watched series", "Recently added videos"
      ])
    end

    it "shows the serie once, not its episodes, in Last watched series" do
      watch_episode("Pilot Episode Kappa", at: 2.hours.ago)
      watch_episode("Second Episode Kappa", at: 1.hour.ago)

      get root_path
      expect(rail_cards("Last watched series")).to eq([ "Serie Kappa" ])
    end

    it "keeps movies and episodes out of Last watched videos" do
      watch(create(:video, kind: :standalone, title: "Clip Kappa"))
      movie = create(:movie, title: "Movie Kappa", video: create(:video, kind: :feature, title: "Feature Kappa"))
      watch(movie.video)
      watch_episode("Episode Kappa")

      get root_path
      expect(rail_cards("Last watched videos")).to eq([ "Clip Kappa" ])
      expect(rail_cards("Last watched movies")).to eq([ "Movie Kappa" ])
    end

    it "orders each rail by the most recent watch" do
      watch(create(:movie, title: "Old Movie Kappa").video, at: 2.days.ago)
      watch(create(:movie, title: "New Movie Kappa").video, at: 1.hour.ago)

      get root_path
      expect(rail_cards("Last watched movies")).to eq([ "New Movie Kappa", "Old Movie Kappa" ])
    end

    it "hides the three rails when the member has no matching history" do
      create(:movie)
      create(:video, kind: :standalone)

      get root_path
      expect(rail_titles).not_to include("Last watched videos", "Last watched movies", "Last watched series")
    end

    it "does not surface a serie through a restricted episode while locked" do
      # A mixed serie stays listed (SeriePolicy), so only the watched-episode
      # filter can keep it out of the rail.
      create(:episode, season: season, video: create(:video, kind: :episode))
      video = create(:video, kind: :episode, visibility: :restricted, maturity_rating: :A18)
      create(:episode, season: season, video: video)
      watch(video)

      get root_path
      expect(rail_cards("Last watched series")).to be_empty
    end
  end

  describe "public-only content (US4)" do
    it "excludes private and unlisted videos from the home rails" do
      create(:video, kind: :standalone, visibility: :public, title: "Public Clip Zeta")
      create(:video, kind: :standalone, visibility: :private, title: "Private Clip Zeta")
      create(:video, kind: :standalone, visibility: :unlisted, title: "Unlisted Clip Zeta")
      sign_in(create(:user, password: "password123"))

      get root_path
      expect(response.body).to include("Public Clip Zeta")
      expect(response.body).not_to include("Private Clip Zeta")
      expect(response.body).not_to include("Unlisted Clip Zeta")
    end
  end
end
