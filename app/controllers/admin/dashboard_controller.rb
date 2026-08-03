module Admin
  # Admin landing page: high-level metrics plus a recent slice of each area.
  class DashboardController < AdminController
    RECENT_LIMIT = 8

    def show
      @users_count = User.count
      @videos_count = Video.count
      @movies_count = Movie.count
      @playlists_count = Playlist.count
      @comments_count = Comment.count

      # Recent rails stay public-only, matching the user detail page: a landing
      # page should not be where private or restricted titles surface. The full,
      # PIN-gated view lives on the per-user see-all pages.
      @recent_videos = Video.visibility_public.recent
                            .includes(:uploader).limit(RECENT_LIMIT)
      @recent_movies = Movie.recent.limit(RECENT_LIMIT)
      @recent_playlists = Playlist.order(created_at: :desc)
                                  .includes(:user, :playlist_items).limit(RECENT_LIMIT)
      @recent_users = User.order(created_at: :desc).limit(RECENT_LIMIT)
      @recent_comments = Comment.order(created_at: :desc)
                                .includes(:user, :video).limit(RECENT_LIMIT)
    end
  end
end
