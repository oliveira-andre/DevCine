module Admin
  # Genre management: the taxonomy behind the catalog filters and genre browse.
  # Previously seed-only; this is full CRUD. Assigning genres to titles happens
  # in the catalog edit form (the API import carries no genre data), so a
  # genre's detail page is where you see what currently carries it.
  class GenresController < AdminController
    include Paginatable
    include ModalLayout

    before_action :set_genre, only: %i[show edit update destroy]

    def index
      @query = params[:q].to_s.strip
      # Correlated subquery for the title count — one query for the whole list
      # (no N+1) and it doesn't break pagy's count the way a GROUP BY would.
      scope = Genre.select(
        "genres.*, (SELECT COUNT(*) FROM taggings WHERE taggings.genre_id = genres.id) AS titles_count"
      ).order(:name)
      scope = scope.where("name ILIKE ?", "%#{Genre.sanitize_sql_like(@query)}%") if @query.present?
      @pagy, @genres = paginate(scope, limit: 30)
    end

    def show
      @movies = @genre.movies.recent.with_attached_poster.limit(24)
      @series = @genre.series.recent.with_attached_poster.limit(24)
    end

    def new
      @genre = Genre.new
    end

    def edit; end

    def create
      @genre = Genre.new(genre_params)
      if @genre.save
        render turbo_stream: [
          turbo_stream.prepend("admin_genres", partial: "admin/genres/row", locals: { item: @genre }),
          turbo_stream.update("admin_genres_empty", ""),
          turbo_stream.update("modal", "")
        ]
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @genre.update(genre_params)
        render turbo_stream: [
          turbo_stream.replace("admin_genre_row_#{@genre.id}", partial: "admin/genres/row", locals: { item: @genre }),
          turbo_stream.update("modal", "")
        ]
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @genre.destroy
      render turbo_stream: turbo_stream.remove("admin_genre_row_#{@genre.id}")
    end

    private

      def set_genre
        @genre = Genre.friendly.find(params[:id])
      end

      def genre_params
        params.require(:genre).permit(:name)
      end
  end
end
