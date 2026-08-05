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

  describe "full edit (feature 013)" do
    let(:movie) do
      create(:movie, title: "Full Edit Movie",
                     video: create(:video, :with_file, kind: :feature, visibility: :public))
    end
    let(:action) { create(:genre, name: "Action") }
    let(:drama) { create(:genre, name: "Drama") }

    def patch_movie(params)
      patch admin_catalog_item_path("movie", movie),
            params: params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    it "renders every field on the movie edit modal" do
      action
      get edit_admin_catalog_item_path("movie", movie), headers: { "Turbo-Frame" => "modal" }

      expect(response.body).to include('name="original_title"')
      expect(response.body).to include('name="release_date"')
      expect(response.body).to include('name="maturity_rating"')
      expect(response.body).to include('name="visibility"')
      expect(response.body).to include('name="genre_ids[]"')
      expect(response.body).to include('name="poster"')
      expect(response.body).to include('name="backdrop"')
    end

    it "updates maturity, original title and release date" do
      patch_movie(title: "Full Edit Movie", original_title: "Le Film",
                  maturity_rating: "A16", release_date: "1999-03-31")

      movie.reload
      expect(movie.maturity_rating).to eq("A16")
      expect(movie.original_title).to eq("Le Film")
      expect(movie.release_date).to eq(Date.new(1999, 3, 31))
    end

    it "sets the movie's genre taggings from the checkboxes" do
      patch_movie(title: "Full Edit Movie", genre_ids: [ "", action.id, drama.id ])

      expect(movie.reload.genres).to contain_exactly(action, drama)
    end

    it "clears taggings when only the sentinel is submitted" do
      create(:tagging, genre: action, taggable: movie)

      patch_movie(title: "Full Edit Movie", genre_ids: [ "" ])

      expect(movie.reload.genres).to be_empty
    end

    it "leaves taggings alone on a title-only update (no genre_ids param)" do
      create(:tagging, genre: action, taggable: movie)

      patch_movie(title: "Renamed", description: "d")

      expect(movie.reload.genres).to contain_exactly(action)
    end

    it "applies visibility to the movie's video" do
      patch_movie(title: "Full Edit Movie", visibility: "unlisted")

      expect(movie.reload.video.visibility).to eq("unlisted")
    end

    it "pairs restricted visibility with an A18 video rating" do
      patch_movie(title: "Full Edit Movie", visibility: "restricted")

      movie.reload
      expect(movie.video.visibility).to eq("restricted")
      expect(movie.video.maturity_rating).to eq("A18")
    end

    it "attaches a new poster" do
      patch_movie(title: "Full Edit Movie",
                  poster: fixture_file_upload("spec/fixtures/files/sample_image.jpg", "image/jpeg"))

      expect(movie.reload.poster).to be_attached
    end

    describe "series" do
      let(:serie) { create(:serie, title: "Full Edit Show", status: :ongoing) }

      it "shows status (not visibility) and updates it" do
        get edit_admin_catalog_item_path("serie", serie), headers: { "Turbo-Frame" => "modal" }
        expect(response.body).to include('name="status"')
        expect(response.body).not_to include('name="visibility"')

        patch admin_catalog_item_path("serie", serie),
              params: { title: "Full Edit Show", status: "ended" },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(serie.reload.status).to eq("ended")
      end

      it "sets serie genre taggings" do
        patch admin_catalog_item_path("serie", serie),
              params: { title: "Full Edit Show", genre_ids: [ "", action.id ] },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(serie.reload.genres).to contain_exactly(action)
      end

      it "attaches a poster to a serie (multipart upload)" do
        patch admin_catalog_item_path("serie", serie),
              params: { title: "Full Edit Show",
                        poster: fixture_file_upload("spec/fixtures/files/sample_image.jpg", "image/jpeg") }

        expect(serie.reload.poster).to be_attached
      end

      it "renders the edit form as a multipart <form>" do
        get edit_admin_catalog_item_path("serie", serie), headers: { "Turbo-Frame" => "modal" }

        expect(response.body).to include('enctype="multipart/form-data"')
      end
    end
  end

  describe "episode rename (feature 013)" do
    let(:serie) { create(:serie, title: "Renamable Show") }
    let(:season) { serie.seasons.create!(name: "Season 1", position: 1) }
    let(:episode) do
      season.episodes.create!(title: "Old Name", position: 1,
                              video: create(:video, kind: :episode, visibility: :public))
    end

    it "renders the episode edit modal with the current title" do
      get edit_episode_admin_catalog_item_path("serie", serie, episode_id: episode.id),
          headers: { "Turbo-Frame" => "modal" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Old Name")
      expect(response.body).to include('name="episode[title]"')
    end

    it "updates the episode title and position" do
      patch episode_admin_catalog_item_path("serie", serie, episode_id: episode.id),
            params: { episode: { title: "New Name", position: 2 } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      episode.reload
      expect(episode.title).to eq("New Name")
      expect(episode.position).to eq(2)
      expect(response.body).to include("admin_episode_#{episode.id}")
    end

    it "rejects a blank title" do
      patch episode_admin_catalog_item_path("serie", serie, episode_id: episode.id),
            params: { episode: { title: "" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html, text/html", "Turbo-Frame" => "modal" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(episode.reload.title).to eq("Old Name")
    end

    # An episode can only be renamed through its own serie — no cross-serie IDOR.
    it "404s for an episode that belongs to a different serie" do
      other = create(:serie, title: "Other Show")

      patch episode_admin_catalog_item_path("serie", other, episode_id: episode.id),
            params: { episode: { title: "Hijacked" } }

      expect(response).to have_http_status(:not_found)
      expect(episode.reload.title).to eq("Old Name")
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

    # Large files arrive via ChunkedUpload (streamed to /admin/chunked_uploads)
    # rather than one multipart POST — the upload action then attaches the
    # reassembled scratch file exactly like a direct upload.
    describe "chunked (resumable) uploads" do
      let(:upload_id) { "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee" }

      after { FileUtils.rm_rf(ChunkedUpload.dir_for(admin)) }

      def stream_chunks(*parts)
        parts.each_with_index do |bytes, index|
          post admin_chunked_uploads_path, params: {
            upload_id: upload_id, index: index,
            chunk: Rack::Test::UploadedFile.new(StringIO.new(bytes), "application/octet-stream", original_filename: "chunk.bin")
          }
          expect(response).to have_http_status(:ok)
        end
      end

      it "attaches an episode placeholder from a file streamed in chunks" do
        serie = CatalogImport.vanilla!(kind: "serie", title: "Chunk Show", seasons_count: 1, uploader: admin)
        season = serie.seasons.first
        placeholder = Video.create!(title: "Chunk Show S1E1", kind: :episode, status: :uploading,
                                    visibility: :private, uploader: admin)
        season.episodes.create!(video: placeholder, title: "Episode 1", position: 1)

        stream_chunks("chunk-one-", "chunk-two")
        post upload_admin_catalog_item_path("serie", serie), params: {
          video_id: placeholder.id, chunked_upload_id: upload_id,
          chunked_upload_filename: "big.mp4", chunked_upload_content_type: "video/mp4"
        }

        placeholder.reload
        expect(placeholder.file).to be_attached
        expect(placeholder.file.filename.to_s).to eq("big.mp4")
        expect(placeholder.file.download).to eq("chunk-one-chunk-two")
        expect(placeholder).to have_attributes(status: "ready", visibility: "public")
      end

      it "deletes the scratch file once the bytes are in Active Storage" do
        serie = CatalogImport.vanilla!(kind: "serie", title: "Sweep Show", seasons_count: 1, uploader: admin)
        season = serie.seasons.first

        stream_chunks("bytes")
        expect(ChunkedUpload.new(admin, upload_id).exists?).to be(true)

        post upload_admin_catalog_item_path("serie", serie), params: {
          season_id: season.id, chunked_upload_id: upload_id,
          chunked_upload_filename: "clip.mp4", chunked_upload_content_type: "video/mp4"
        }

        expect(ChunkedUpload.new(admin, upload_id).exists?).to be(false)
      end

      it "rejects a chunk with a non-UUID upload id" do
        post admin_chunked_uploads_path, params: {
          upload_id: "../escape", index: 0,
          chunk: Rack::Test::UploadedFile.new(StringIO.new("x"), "application/octet-stream", original_filename: "chunk.bin")
        }
        expect(response).to have_http_status(:bad_request)
      end

      it "requires admin to stream chunks" do
        sign_in(create(:user, password: "password123"))
        post admin_chunked_uploads_path, params: {
          upload_id: upload_id, index: 0,
          chunk: Rack::Test::UploadedFile.new(StringIO.new("x"), "application/octet-stream", original_filename: "chunk.bin")
        }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
