module Admin
  # Catalog creation wizard: movies / series / anime, either "vanilla" (manual)
  # or API-assisted (CatalogLookup chains: TMDB→Fanart, TMDB→Fanart→TVmaze,
  # AniList→TMDB). Wizard steps render into the shared modal; the created item
  # lands on a per-item upload page where each episode/movie slot takes a file.
  class CatalogController < AdminController
    include ModalLayout

    KINDS = CatalogLookup::KINDS

    # Filterable list: title search + genre (taggings), maturity, kind
    # (movie/serie) and visibility (via the underlying videos).
    def index
      @query = params[:q].to_s.strip
      @genres = Genre.pill_list
      @movies = filtered(Movie.recent.with_attached_poster.includes(:genres), :movie)
      @series = filtered(Serie.recent.with_attached_poster.includes(:genres, :seasons), :serie)
    end

    # Remove an item AND its owned videos (a movie's feature video cascades the
    # movie row; a serie's episode videos cascade their episode rows).
    def destroy
      if params[:type] == "movie"
        movie = Movie.find(params[:id])
        title = movie.title
        movie.video.destroy!
      else
        serie = Serie.friendly.find(params[:id])
        title = serie.title
        serie.videos.find_each(&:destroy!)
        serie.destroy!
      end
      redirect_to admin_catalog_index_path, notice: "“#{title}” was deleted successfully."
    end

    # Step 1 (modal): pick content type + creation mode.
    def new; end

    # Step 1 → 2 dispatcher: routes to the vanilla form or the API search.
    def start
      kind = params[:kind].presence_in(KINDS) || "movie"
      if params[:mode] == "api"
        redirect_to search_admin_catalog_index_path(kind: kind)
      else
        redirect_to vanilla_admin_catalog_index_path(kind: kind)
      end
    end

    # Step 2 (modal, vanilla): name (+ seasons when a serie/anime).
    def vanilla
      @kind = params[:kind].presence_in(KINDS) || "movie"
    end

    def create
      @kind = params[:kind].presence_in(KINDS) || "movie"
      title = params[:title].to_s.strip
      if title.blank?
        @error = "Title is required."
        render :vanilla, status: :unprocessable_entity
        return
      end

      item = CatalogImport.vanilla!(
        kind: @kind, title: title, description: params[:description].presence,
        seasons_count: params[:seasons_count], uploader: Current.user
      )
      flash[:notice] = "“#{item.title}” was created successfully — upload the videos below."
      visit_item(item)
    rescue ActiveRecord::RecordInvalid => e
      @error = "Could not create: #{e.message}"
      render :vanilla, status: :unprocessable_entity
    end

    # Step 2 (modal, API): search across the gateway chain, list picks.
    def search
      @kind = params[:kind].presence_in(KINDS) || "movie"
      @query = params[:q].to_s.strip
      @results = @query.present? ? CatalogLookup.search(@kind, @query) : []
    end

    # Step 3: import the picked result (details + seasons + placeholders + poster).
    # Failures re-render the search modal with the error inline.
    def import
      @kind = params[:kind].presence_in(KINDS) || "movie"
      item = CatalogImport.from_api!(
        kind: @kind, source: params[:source], external_id: params[:external_id],
        uploader: Current.user
      )
      if item
        slots = item.is_a?(Movie) ? 1 : Episode.joins(:season).where(seasons: { serie_id: item.id }).count
        flash[:notice] = "“#{item.title}” was imported successfully — #{pluralize_slots(slots)} ready for upload."
        visit_item(item)
      else
        search_again_with_error("Could not import that title — try another result.")
      end
    rescue ActiveRecord::RecordInvalid => e
      search_again_with_error("Import failed: #{e.message}")
    end

    # Upload management page for a created item.
    def show
      set_item
      if @item.is_a?(Serie)
        @seasons = @item.seasons.order(:position).includes(episodes: { video: :file_attachment })
      end
    end

    # Edit modal: title + description (reachable from the list row pencil and
    # the item page's Edit button).
    def edit
      set_item
      @genres = Genre.order(:name)
    end

    def update
      set_item
      assign_item_attributes

      if @item.save
        apply_movie_visibility
        apply_chosen_thumbnail
        flash.now[:notice] = "“#{@item.title}” was saved successfully."
        render turbo_stream: [
          turbo_stream.update("modal", ""),
          # List row (admin/catalog) and item page header — whichever is on the
          # page gets refreshed; absent targets are ignored by Turbo.
          turbo_stream.replace(helpers.dom_id(@item, :admin), partial: "admin/catalog/item", locals: { item: @item }),
          turbo_stream.update("admin_item_title", @item.title),
          turbo_stream.replace("admin_item_summary", partial: "admin/catalog/summary", locals: { item: @item }),
          turbo_stream.update("flash", partial: "shared/flash")
        ]
      else
        @genres = Genre.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    # Attach a file to a placeholder video, or add a brand-new episode.
    def upload
      file = resolved_upload_file
      if file.blank?
        redirect_to admin_catalog_item_path(params[:type], params[:id]),
                    alert: "No file received — please pick a video file."
        return
      end

      set_item
      saved =
        if params[:video_id].present?
          fill_placeholder(find_slot_video(params[:video_id]), file)
        elsif params[:season_id].present?
          @season = @item.seasons.find(params[:season_id])
          @new_episode = add_episode(@season, file)
          @new_episode.video
        end

      # The bytes are now copied into Active Storage — drop the chunk scratch file.
      @chunked_upload&.discard

      # The slot is updated IN PLACE (row swap / new row + a fresh add form), so
      # nothing depends on a page reload — choosing, skipping or plain ✕-closing
      # the chooser modal all leave a correct page behind. Frames are offered
      # best-effort: if ffmpeg produces nothing, the streams just carry a toast.
      streams = upload_row_streams(saved)
      if saved&.suggest_thumbnails!
        streams << turbo_stream.update("modal", partial: "admin/catalog/thumbnail_chooser",
                                                locals: { video: saved, item: @item, type: params[:type] })
      else
        flash.now[:notice] = "Video “#{saved&.title}” was saved successfully."
        streams << turbo_stream.update("flash", partial: "shared/flash")
      end
      render turbo_stream: streams
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_catalog_item_path(params[:type], params[:id]), alert: e.message
    end

    # Promote a suggested frame for a just-uploaded slot. The row is already
    # correct (updated by #upload), so the answer only closes the modal.
    def choose_thumbnail
      set_item
      video = find_slot_video(params[:video_id])
      if video.accept_thumbnail_candidate(params[:signed_id])
        close_chooser(notice: "Thumbnail set.")
      else
        close_chooser(alert: "That suggestion is no longer available.")
      end
    end

    # Decline the suggestions and keep the slot as it is.
    def skip_thumbnail
      set_item
      video = find_slot_video(params[:video_id])
      video.clear_thumbnail_candidates!
      close_chooser(notice: "Saved without a thumbnail.")
    end

    # Remove an uploaded file so a new one can be dropped: purge the attachment
    # and revert the video to its hidden placeholder state.
    def remove_upload
      video = Video.find(params[:video_id])
      video.file.purge if video.file.attached?
      video.update!(status: :uploading, visibility: :private)
      redirect_to admin_catalog_item_path(params[:type], params[:id]),
                  notice: "Video “#{video.title}” file was deleted successfully — drop a new one when ready."
    end

    # Rename / reposition an episode (renders the modal form).
    def edit_episode
      set_item
      @episode = find_episode
    end

    def update_episode
      set_item
      @episode = find_episode
      if @episode.update(episode_params)
        render turbo_stream: [
          turbo_stream.replace("admin_episode_#{@episode.id}",
                               partial: "admin/catalog/episode", locals: { episode: @episode, item: @item }),
          turbo_stream.update("modal", "")
        ]
      else
        render :edit_episode, status: :unprocessable_entity
      end
    end

    private

    def type_of(item) = item.is_a?(Movie) ? "movie" : "serie"

    # The episode, scoped through the serie's seasons so one serie can't touch
    # another's episodes.
    def find_episode
      Episode.joins(:season).where(seasons: { serie_id: @item.id }).find(params[:episode_id])
    end

    def episode_params
      params.require(:episode).permit(:title, :position)
    end

    # Full-edit field assignment (feature 013). Shared columns plus the ones
    # that only one type has (original_title on Movie, status on Serie), the
    # genre taggings, and the images. Blank strings are treated as "leave alone"
    # for the date so clearing the field doesn't wipe a release date by accident.
    def assign_item_attributes
      # key? not present?: a blank title must still be assigned so validation
      # catches it rather than silently keeping the old one.
      @item.title = params[:title].to_s.strip if params.key?(:title)
      @item.description = params[:description] if params.key?(:description)
      @item.release_date = params[:release_date] if params.key?(:release_date)
      @item.maturity_rating = params[:maturity_rating] if params[:maturity_rating].present?
      @item.original_title = params[:original_title] if @item.respond_to?(:original_title=) && params.key?(:original_title)
      @item.status = params[:status] if @item.respond_to?(:status=) && params[:status].present?

      # genre_ids= replaces the taggings wholesale. Only sync when the form
      # actually submitted them — the edit form carries a hidden "" sentinel so
      # the key is always present, even with every box unchecked; a title-only
      # update (no genre_ids at all) must leave existing taggings untouched.
      @item.genre_ids = Array(params[:genre_ids]).reject(&:blank?) if params.key?(:genre_ids)

      @item.poster.attach(params[:poster]) if params[:poster].present?
      @item.backdrop.attach(params[:backdrop]) if params[:backdrop].present?
    end

    # A movie's visibility lives on its single video. A serie's visibility is
    # per-episode, so it is left to the Video admin. Restricted implies A18 (the
    # video model enforces it), so pair them.
    def apply_movie_visibility
      return unless @item.is_a?(Movie) && params[:visibility].present?
      return unless @item.video

      attrs = { visibility: params[:visibility] }
      attrs[:maturity_rating] = :A18 if params[:visibility] == "restricted"
      @item.video.update(attrs)
    end

    # The edit modal offers ffmpeg frame suggestions (lazy turbo frame) when a
    # movie's video has no thumbnail; the picked radio rides along with the
    # form as video[thumbnail_signed_id] — same contract as the member upload.
    # Accepting also clears the remaining candidates.
    def apply_chosen_thumbnail
      chosen = params.dig(:video, :thumbnail_signed_id)
      return if chosen.blank? || !@item.is_a?(Movie) || @item.video.nil?

      @item.video.accept_thumbnail_candidate(chosen)
    end

    # Movies are addressed by uuid, series by friendly slug (see routes).
    def set_item
      @item =
        if params[:type] == "movie"
          Movie.with_attached_poster.find(params[:id])
        else
          Serie.with_attached_poster.friendly.find(params[:id])
        end
    end

    def pluralize_slots(count) = "#{count} upload slot#{'s' unless count == 1}"

    # Wizard forms live in the modal frame, so success can't plain-redirect (it
    # would render inside the modal). Close the modal and Turbo-visit the item;
    # the flash set just before survives to that visit.
    def visit_item(item)
      url = admin_catalog_item_path(type_of(item), item)
      render turbo_stream: [
        turbo_stream.update("modal", ""),
        turbo_stream.append("modal", helpers.tag.script("window.Turbo.visit(#{url.to_json})".html_safe))
      ]
    end

    # Re-render the search modal with the error inline (and the results again).
    def search_again_with_error(message)
      @error = message
      @query = params[:q].to_s.strip
      @results = @query.present? ? CatalogLookup.search(@kind, @query) : []
      render :search, status: :unprocessable_entity
    end

    # Applies the index filters to a Movie or Serie scope.
    def filtered(scope, type)
      return scope.none if params[:kind].present? && params[:kind] != type.to_s

      if @query.present?
        scope = scope.where("#{scope.table_name}.title ILIKE ?",
                            "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%")
      end
      scope = scope.joins(:taggings).where(taggings: { genre_id: params[:genre] }) if params[:genre].present?
      if params[:maturity].present? && Movie.maturity_ratings.key?(params[:maturity])
        scope = scope.where(maturity_rating: params[:maturity])
      end
      if params[:visibility].present? && Video.visibilities.key?(params[:visibility])
        scope =
          if type == :movie
            scope.joins(:video).where(videos: { visibility: params[:visibility] })
          else
            scope.joins(:videos).where(videos: { visibility: params[:visibility] }).distinct
          end
      end
      scope.limit(30)
    end

    def fill_placeholder(video, file)
      video.file.attach(file)
      video.update!(status: :ready, visibility: :public)
      video
    end

    def add_episode(season, file)
      position = season.episodes.maximum(:position).to_i + 1
      title = params[:title].presence || "Episode #{position}"
      video = Video.create!(
        title: "#{season.serie.title} S#{season.position}E#{position}",
        kind: :episode, status: :ready, visibility: :public, uploader: Current.user
      )
      video.file.attach(file)
      season.episodes.create!(video: video, title: title, position: position)
    end

    # A slot video may only be addressed through the catalog item that owns it —
    # the movie's own feature video or one of the serie's episode videos.
    def find_slot_video(video_id)
      if @item.is_a?(Movie)
        raise ActiveRecord::RecordNotFound unless @item.video_id.to_s == video_id.to_s

        @item.video
      else
        Video.joins(episodes: :season).where(seasons: { serie_id: @item.id }).find(video_id)
      end
    end

    # Streams that flip the uploaded slot to its settled state: the movie slot
    # or episode row swaps in place; a brand-new episode's row is inserted where
    # it belongs and the add-episode form comes back fresh (clearing its
    # "Uploading…" label) so the next episode can be dropped straight away.
    def upload_row_streams(video)
      if @item.is_a?(Movie)
        [ turbo_stream.replace("admin_movie_slot_#{@item.id}",
                               partial: "admin/catalog/movie_slot", locals: { item: @item }) ]
      elsif @new_episode
        [ turbo_stream.before("admin_add_episode_#{@season.id}",
                              partial: "admin/catalog/episode",
                              locals: { episode: @new_episode, item: @item }),
          turbo_stream.replace("admin_add_episode_#{@season.id}",
                               partial: "admin/catalog/add_episode",
                               locals: { season: @season, item: @item }) ]
      else
        episode = Episode.joins(:season).where(seasons: { serie_id: @item.id }).find_by!(video_id: video.id)
        [ turbo_stream.replace("admin_episode_#{episode.id}",
                               partial: "admin/catalog/episode",
                               locals: { episode: episode, item: @item }) ]
      end
    end

    def close_chooser(notice: nil, alert: nil)
      flash.now[:notice] = notice if notice
      flash.now[:alert] = alert if alert
      render turbo_stream: [
        turbo_stream.update("modal", ""),
        turbo_stream.update("flash", partial: "shared/flash")
      ]
    end

    # The video slot either arrives as a direct multipart upload (small files)
    # or was streamed ahead of time in chunks (large files) — see ChunkedUpload.
    # Returns something Active Storage can attach, or nil when neither is present.
    def resolved_upload_file
      return params[:file] if params[:file].present?
      return nil if params[:chunked_upload_id].blank?

      @chunked_upload = ChunkedUpload.new(Current.user, params[:chunked_upload_id])
      @chunked_upload.to_attachable(
        filename: params[:chunked_upload_filename],
        content_type: params[:chunked_upload_content_type]
      )
    rescue ChunkedUpload::InvalidId
      nil
    end
  end
end
