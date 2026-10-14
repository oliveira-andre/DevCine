class HomeController < ApplicationController
  include Paginatable

  # Authenticated by default via the Authentication concern (no opt-out).
  # Every rail flows through the Pundit policy scopes (feature 006, FR-017):
  # public content always; restricted only while PIN-unlocked. Each rail renders
  # page 1 and lazily appends further pages from its matching section endpoint.
  def index
    # Hero/card partials reach movie.video (player link + hover preview), so
    # eager-load it to avoid per-movie queries.
    @hero_movies = policy_scope(Movie).hero.with_attached_backdrop.includes(:video)

    @videos_pagy, @recent_videos = paginate(
      policy_scope(Video).standalone.recent.with_attached_thumbnail.with_attached_preview, limit: 50
    )
    @movies_pagy, @recent_movies = paginate(
      policy_scope(Movie).recent.with_attached_poster.includes(video: :preview_attachment), limit: 20
    )
    @series_pagy, @recent_series = paginate(policy_scope(Serie).recent.with_attached_poster, limit: 20)

    last_watched = WatchProgress.recent_for(Current.user)
                                .joins(:video).merge(policy_scope(Video))
                                .includes(video: [ :thumbnail_attachment, :preview_attachment ])
    @last_watched = last_watched.limit(20)
    # Same "videos" definition as the Recently added videos rail.
    @last_watched_videos = last_watched.merge(Video.standalone).limit(20)
    @last_watched_movies = policy_scope(Movie).last_watched_by(Current.user)
                                              .with_attached_poster.includes(video: :preview_attachment)
                                              .limit(20)
    # One card per serie; only episodes the viewer may still see count (a
    # restricted episode watched earlier must not surface its serie while locked).
    @last_watched_series = policy_scope(Serie).last_watched_by(Current.user)
                                              .merge(policy_scope(Video))
                                              .with_attached_poster.limit(20)
  end
end
