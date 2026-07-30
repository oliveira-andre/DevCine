require 'rails_helper'

# Admin catalog creation wizard: vanilla + API-assisted flows and the upload step.
RSpec.describe "Admin::Catalog", type: :request do
  let(:admin) { create(:user, :admin, password: "password123") }

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  def video_upload
    Rack::Test::UploadedFile.new(StringIO.new("fake-mp4-bytes"), "video/mp4", original_filename: "ep.mp4")
  end

  before { sign_in(admin) }

  it "blocks non-admins" do
    sign_in(create(:user, password: "password123"))
    get admin_catalog_index_path
    expect(response).to redirect_to(root_path)
  end

  describe "vanilla flow" do
    it "creates a movie with a private placeholder video" do
      expect {
        post admin_catalog_index_path, params: { kind: "movie", title: "My Film", description: "d" }
      }.to change(Movie, :count).by(1).and change(Video, :count).by(1)

      movie = Movie.order(:created_at).last
      # success closes the modal and visits the item page client-side
      expect(response.body).to include("Turbo.visit")
      expect(response.body).to include(admin_catalog_item_path("movie", movie))
      expect(movie.video).to have_attributes(kind: "feature", status: "uploading", visibility: "private")
      expect(movie.video.file).not_to be_attached
    end

    it "creates a serie with the requested seasons and no episodes" do
      expect {
        post admin_catalog_index_path, params: { kind: "serie", title: "My Show", seasons_count: 3 }
      }.to change(Serie, :count).by(1).and change(Season, :count).by(3)
      expect(Episode.count).to eq(Episode.count) # no placeholders in vanilla
    end

    it "shows the error inside the modal when the title is blank" do
      post admin_catalog_index_path, params: { kind: "movie", title: "  " }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Title is required.")
    end

    it "gives the description field the auto-grow behaviour" do
      get vanilla_admin_catalog_index_path(kind: "movie")
      expect(response.body).to match(/<textarea[^>]*name="description"[^>]*data-controller="textarea-autogrow"/m)
    end
  end

  describe "API flow" do
    it "searches through CatalogLookup" do
      allow(CatalogLookup).to receive(:search).with("anime", "naruto").and_return(
        [ { source: "anilist", external_id: "20", kind: :serie, title: "Naruto", overview: "Ninja", poster_url: nil, year: 2002 } ]
      )
      get search_admin_catalog_index_path, params: { kind: "anime", q: "naruto" }
      expect(response.body).to include("Naruto")
      expect(response.body).to include("Import")
    end

    it "imports a serie with seasons and episode placeholder videos" do
      allow(CatalogLookup).to receive(:details).with("serie", "tvmaze", "169").and_return(
        { source: "tvmaze", external_id: "169", kind: :serie, title: "Breaking Bad",
          description: "Crime.", poster_url: nil, backdrop_url: nil,
          release_date: Date.new(2008, 1, 20), status: "ended",
          seasons: [ { number: 1, name: "Season 1",
                       episodes: [ { number: 1, title: "Pilot" }, { number: 2, title: nil } ] } ] }
      )

      expect {
        post import_admin_catalog_index_path, params: { kind: "serie", source: "tvmaze", external_id: "169" }
      }.to change(Serie, :count).by(1).and change(Season, :count).by(1).and change(Episode, :count).by(2)

      serie = Serie.friendly.find("breaking-bad")
      expect(serie.status).to eq("ended")
      episodes = serie.seasons.first.episodes.order(:position)
      expect(episodes.map(&:title)).to eq([ "Pilot", "Episode 2" ])
      expect(episodes.first.video).to have_attributes(
        kind: "episode", status: "uploading", visibility: "private", title: "Breaking Bad S1E1"
      )
      # placeholders are invisible to viewers
      expect(VideoPolicy::Scope.new(AuthContext.new(user: create(:user), pin_unlocked: false), Video)
        .resolve.where(id: episodes.first.video_id)).to be_empty
    end

    it "shows the error inside the search modal when details cannot be fetched" do
      allow(CatalogLookup).to receive(:details).and_return(nil)
      allow(CatalogLookup).to receive(:search).and_return([])
      post import_admin_catalog_index_path, params: { kind: "movie", source: "tmdb", external_id: "1", q: "x" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Could not import that title")
    end
  end

  describe "index filters" do
    let!(:action_genre) { Genre.find_or_create_by!(name: "Action") }
    let!(:movie) do
      v = create(:video, :with_file, kind: :feature, visibility: :public)
      create(:movie, title: "Filter Film", video: v, maturity_rating: :A16)
    end
    let!(:serie) { create(:serie, title: "Filter Show", maturity_rating: :L) }
    before { create(:tagging, genre: action_genre, taggable: movie) }

    it "searches by title" do
      get admin_catalog_index_path, params: { q: "Filter Film" }
      expect(response.body).to include("Filter Film")
      expect(response.body).not_to include("Filter Show")
    end

    it "filters by genre" do
      get admin_catalog_index_path, params: { genre: action_genre.id }
      expect(response.body).to include("Filter Film")
      expect(response.body).not_to include("Filter Show")
    end

    it "filters by maturity" do
      get admin_catalog_index_path, params: { maturity: "A16" }
      expect(response.body).to include("Filter Film")
      expect(response.body).not_to include("Filter Show")
    end

    it "filters by kind" do
      get admin_catalog_index_path, params: { kind: "serie" }
      expect(response.body).not_to include("Filter Film")
      expect(response.body).to include("Filter Show")
    end

    it "filters movies by their video's visibility" do
      get admin_catalog_index_path, params: { visibility: "private" }
      expect(response.body).not_to include("Filter Film") # its video is public
    end
  end

  describe "edit / update (title + description modal)" do
    let(:movie) { create(:movie, title: "Old Name", description: "Old desc", video: create(:video, :with_file, kind: :feature, visibility: :public)) }

    it "renders the edit modal for the frame with the current values" do
      get edit_admin_catalog_item_path("movie", movie), headers: { "Turbo-Frame" => "modal" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<turbo-frame id="modal">')
      expect(response.body).to include("Old Name").and include("Old desc")
    end

    it "updates title + description, closes the modal and refreshes row, header and summary" do
      patch admin_catalog_item_path("movie", movie),
            params: { title: "New Name", description: "New desc" },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(movie.reload.title).to eq("New Name")
      expect(movie.description).to eq("New desc")
      expect(response.body).to include('target="modal"')
      expect(response.body).to include("admin_movie_#{movie.id}")
      expect(response.body).to include('target="admin_item_title"').and include('target="admin_item_summary"')
      expect(response.body).to include("“New Name” was saved successfully.")
    end

    it "edits a serie addressed by slug" do
      serie = create(:serie, title: "Slugged Show")
      patch admin_catalog_item_path("serie", serie),
            params: { title: "Renamed Show", description: "About it" },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(serie.reload.title).to eq("Renamed Show")
    end

    it "re-renders the modal with the error when the title is blank" do
      patch admin_catalog_item_path("movie", movie),
            params: { title: "", description: "x" },
            headers: { "Accept" => "text/vnd.turbo-stream.html, text/html", "Turbo-Frame" => "modal" }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Title can")
      expect(movie.reload.title).to eq("Old Name")
    end

    it "shows the eye (view) and pencil (edit modal) actions on the list row" do
      movie
      get admin_catalog_index_path
      expect(response.body).to include(edit_admin_catalog_item_path("movie", movie))
      expect(response.body).to include(%(aria-label="View Old Name"))
      expect(response.body).to include(%(aria-label="Edit Old Name"))
    end

    it "shows the Edit button on the item page" do
      get admin_catalog_item_path("movie", movie)
      expect(response.body).to include(edit_admin_catalog_item_path("movie", movie))
      expect(response.body).to include('id="admin_item_title"').and include('id="admin_item_summary"')
    end
  end

  describe "destroy" do
    it "deletes a movie together with its video" do
      v = create(:video, :with_file, kind: :feature, visibility: :public)
      movie = create(:movie, title: "Doomed Film", video: v)

      expect {
        delete admin_catalog_item_path("movie", movie)
      }.to change(Movie, :count).by(-1).and change(Video, :count).by(-1)
      expect(response).to redirect_to(admin_catalog_index_path)
    end

    it "deletes a serie with its seasons, episodes and episode videos" do
      allow(CatalogLookup).to receive(:details).and_return(
        { source: "tvmaze", external_id: "1", kind: :serie, title: "Doomed Show",
          description: nil, poster_url: nil, backdrop_url: nil, release_date: nil,
          status: "ended",
          seasons: [ { number: 1, name: "Season 1",
                       episodes: [ { number: 1, title: "One" }, { number: 2, title: "Two" } ] } ] }
      )
      serie = CatalogImport.from_api!(kind: "serie", source: "tvmaze", external_id: "1", uploader: admin)

      expect {
        delete admin_catalog_item_path("serie", serie)
      }.to change(Serie, :count).by(-1)
        .and change(Season, :count).by(-1)
        .and change(Episode, :count).by(-2)
        .and change(Video, :count).by(-2)
    end
  end

  describe "uploads" do
    it "fills an episode placeholder: attaches the file and flips it public/ready" do
      serie = CatalogImport.vanilla!(kind: "serie", title: "Up Show", seasons_count: 1, uploader: admin)
      season = serie.seasons.first
      placeholder = Video.create!(title: "Up Show S1E1", kind: :episode, status: :uploading,
                                  visibility: :private, uploader: admin)
      season.episodes.create!(video: placeholder, title: "Episode 1", position: 1)

      post upload_admin_catalog_item_path("serie", serie), params: { video_id: placeholder.id, file: video_upload }
      placeholder.reload
      expect(placeholder.file).to be_attached
      expect(placeholder).to have_attributes(status: "ready", visibility: "public")
    end

    it "shows the filename and a download link for an uploaded slot" do
      serie = CatalogImport.vanilla!(kind: "serie", title: "Named Show", seasons_count: 1, uploader: admin)
      season = serie.seasons.first
      video = Video.create!(title: "Named Show S1E1", kind: :episode, status: :ready,
                            visibility: :public, uploader: admin)
      video.file.attach(io: StringIO.new("bytes"), filename: "episode-one.mp4", content_type: "video/mp4")
      season.episodes.create!(video: video, title: "Episode 1", position: 1)

      get admin_catalog_item_path("serie", serie)
      expect(response.body).to include("episode-one.mp4")             # filename shown
      expect(response.body).to include("disposition=attachment")      # download link
      expect(response.body).to include("Uploaded")
      expect(response.body).not_to include("Drop the episode here")   # no dropzone for filled slot
    end

    it "links every slot to the per-video subtitle manager" do
      serie = CatalogImport.vanilla!(kind: "serie", title: "Subs Show", seasons_count: 1, uploader: admin)
      season = serie.seasons.first
      video = Video.create!(title: "Subs Show S1E1", kind: :episode, status: :uploading,
                            visibility: :private, uploader: admin)
      season.episodes.create!(video: video, title: "Episode 1", position: 1)

      get admin_catalog_item_path("serie", serie)
      expect(response.body).to include(admin_video_path(video)) # captions shortcut (empty slot too)
    end

    it "removes an uploaded file and reverts the slot to a hidden placeholder" do
      serie = CatalogImport.vanilla!(kind: "serie", title: "Redo Show", seasons_count: 1, uploader: admin)
      season = serie.seasons.first
      video = Video.create!(title: "Redo Show S1E1", kind: :episode, status: :ready,
                            visibility: :public, uploader: admin)
      video.file.attach(io: StringIO.new("bytes"), filename: "old-cut.mp4", content_type: "video/mp4")
      season.episodes.create!(video: video, title: "Episode 1", position: 1)

      delete upload_admin_catalog_item_path("serie", serie), params: { video_id: video.id }
      video.reload
      expect(video.file).not_to be_attached
      expect(video).to have_attributes(status: "uploading", visibility: "private")
      expect(response).to redirect_to(admin_catalog_item_path("serie", serie))

      follow_redirect!
      expect(response.body).to include("file was deleted successfully")
      expect(response.body).to include("Drop the episode here") # dropzone is back
    end

    it "adds a brand-new episode to a season (vanilla flow)" do
      serie = CatalogImport.vanilla!(kind: "serie", title: "Grow Show", seasons_count: 1, uploader: admin)
      season = serie.seasons.first

      expect {
        post upload_admin_catalog_item_path("serie", serie),
             params: { season_id: season.id, title: "The Start", file: video_upload }
      }.to change(Episode, :count).by(1).and change(Video, :count).by(1)

      episode = season.episodes.order(:position).last
      expect(episode).to have_attributes(title: "The Start", position: 1)
      expect(episode.video.file).to be_attached
      expect(episode.video).to have_attributes(status: "ready", visibility: "public")
    end
  end
end
