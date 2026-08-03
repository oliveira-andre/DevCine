module Admin
  # Admin playlist management: a searchable list across every member, each row
  # expanding to its members. Unlike the public browse this is unscoped — a
  # moderator needs to see private and unlisted lists too — so each row carries
  # a visibility badge, and member titles the admin is not cleared for stay
  # masked behind the PIN (same rule as the user pages).
  class PlaylistsController < AdminController
    include Paginatable

    PAGE_LIMIT = 20

    def index
      @query = params[:q].to_s.strip
      scope = Playlist.order(created_at: :desc).includes(:user, playlist_items: :video)
      if @query.present?
        like = "%#{Playlist.sanitize_sql_like(@query)}%"
        scope = scope.joins(:user).where(
          "playlists.title ILIKE :q OR users.email_address ILIKE :q", q: like
        )
      end
      @pagy, @playlists = paginate(scope, limit: PAGE_LIMIT)
    end

    def destroy
      @playlist = Playlist.find(params[:id])
      @playlist.destroy
      render turbo_stream: turbo_stream.remove("admin_playlist_row_#{@playlist.id}")
    end
  end
end
