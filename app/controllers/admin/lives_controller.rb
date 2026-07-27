module Admin
  # Admin management of embed-based live videos (feature 009). Lives are
  # live-kind Video records with a title and an embed URL (no file).
  class LivesController < AdminController
    include Paginatable
    include ModalLayout

    before_action :set_live, only: %i[edit update destroy]

    # GET /admin/lives — searchable, infinite-scrolled list.
    def index
      @query = params[:q].to_s.strip
      scope = Video.live.recent
      scope = scope.where("videos.title ILIKE ?", "%#{Video.sanitize_sql_like(@query)}%") if @query.present?
      @pagy, @lives = paginate(scope.with_attached_thumbnail, limit: 20)
    end

    def new
      @live = Video.new(kind: :live)
    end

    def edit; end

    # POST /admin/lives — create a live; prepend the row + close the modal.
    def create
      @live = Video.new(live_params.merge(kind: :live, visibility: :public, uploader: Current.user))
      if @live.save
        render turbo_stream: [
          turbo_stream.prepend("admin_lives", partial: "admin/lives/row", locals: { item: @live }),
          turbo_stream.update("modal", "")
        ]
      else
        render :new, status: :unprocessable_entity
      end
    end

    # PATCH /admin/lives/:id — update; replace the row + close the modal.
    def update
      if @live.update(live_params)
        render turbo_stream: [
          turbo_stream.replace("admin_live_row_#{@live.id}", partial: "admin/lives/row", locals: { item: @live }),
          turbo_stream.update("modal", "")
        ]
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/lives/:id — remove; drop the row.
    def destroy
      @live.destroy
      render turbo_stream: turbo_stream.remove("admin_live_row_#{@live.id}")
    end

    private

      def set_live
        @live = Video.live.friendly.find(params[:id])
      end

      def live_params
        params.require(:video).permit(:title, :live_embed_url)
      end
  end
end
