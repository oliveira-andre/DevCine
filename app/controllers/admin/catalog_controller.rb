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
      if params[:file].blank?
        redirect_to admin_catalog_item_path(params[:type], params[:id]),
                    alert: "No file received — please pick a video file."
        return
      end

      saved =
        if params[:video_id].present?
          fill_placeholder(Video.find(params[:video_id]))
        elsif params[:season_id].present?
          add_episode(Season.find(params[:season_id])).video
        end

      item_path = admin_catalog_item_path(params[:type], params[:id])

      # Offer frames from the upload as thumbnail suggestions. Best-effort: if
      # ffmpeg can't produce any, the upload finishes exactly as it used to.
      if saved&.suggest_thumbnails!
        redirect_to thumbnail_suggestions_video_path(saved, return_to: item_path)
      else
        redirect_to item_path, notice: "Video “#{saved&.title}” was saved successfully."
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_catalog_item_path(params[:type], params[:id]), alert: e.message
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

    private

    def type_of(item) = item.is_a?(Movie) ? "movie" : "serie"

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

    def fill_placeholder(video)
      video.file.attach(params[:file])
      video.update!(status: :ready, visibility: :public)
      video
    end

    def add_episode(season)
      position = season.episodes.maximum(:position).to_i + 1
      title = params[:title].presence || "Episode #{position}"
      video = Video.create!(
        title: "#{season.serie.title} S#{season.position}E#{position}",
        kind: :episode, status: :ready, visibility: :public, uploader: Current.user
      )
      video.file.attach(params[:file])
      season.episodes.create!(video: video, title: title, position: position)
    end
  end
end
