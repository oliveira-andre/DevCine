class HomeController < ApplicationController
  include Paginatable

  # Authenticated by default via the Authentication concern (no opt-out).
  # Home shows only PUBLIC content (US4). Each rail renders page 1 and lazily
  # appends further pages from its matching section endpoint (US5); page sizes
  # match the section pages so appended pages are continuous.
  def index
    @hero_movies = Movie.hero.with_attached_backdrop

    @videos_pagy, @recent_videos = paginate(
      Video.standalone.listable.recent.with_attached_thumbnail.with_attached_preview, limit: 50
    )
    @movies_pagy, @recent_movies = paginate(Movie.recent.with_attached_poster, limit: 20)
    @series_pagy, @recent_series = paginate(Serie.recent.with_attached_poster, limit: 20)

    @last_watched = WatchProgress.recent_for(Current.user)
                                 .joins(:video).merge(Video.listable)
                                 .includes(video: [ :thumbnail_attachment, :preview_attachment ])
                                 .limit(20)
  end
end
