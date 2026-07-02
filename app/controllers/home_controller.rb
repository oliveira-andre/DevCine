class HomeController < ApplicationController
  # Authenticated by default via the Authentication concern (no opt-out).
  RAIL_LIMIT = 12

  def index
    @hero_movies = Movie.hero.with_attached_backdrop
    @recent_videos = Video.standalone_recent.with_attached_thumbnail.with_attached_preview.limit(RAIL_LIMIT)
    @recent_movies = Movie.recent.with_attached_poster.limit(RAIL_LIMIT)
    @recent_series = Serie.recent.with_attached_poster.limit(RAIL_LIMIT)
    @last_watched = WatchProgress.recent_for(Current.user)
                                 .includes(video: [ :thumbnail_attachment, :preview_attachment ])
                                 .limit(RAIL_LIMIT)
  end
end
