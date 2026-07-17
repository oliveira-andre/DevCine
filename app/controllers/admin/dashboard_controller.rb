module Admin
  # Admin landing page with high-level site metrics.
  class DashboardController < AdminController
    def show
      @users_count = User.count
      @videos_count = Video.count
      @movies_count = Movie.count
      @playlists_count = Playlist.count
    end
  end
end
