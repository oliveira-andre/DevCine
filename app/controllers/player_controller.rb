class PlayerController < ApplicationController
  include Playable

  # GET /playing/:slug — the full-bleed player page (feature 005, US1).
  # An optional collection context (?serie=slug or ?list=playlist_id) wires the
  # prev/next controls to the real neighbors in that sequence (feature 007).
  def show
    @video = find_playable_video!(scope: Video.with_attached_file.with_attached_thumbnail)
    # Resume where the viewer stopped (skip when they finished the video).
    progress = WatchProgress.find_by(user: Current.user, video: @video)
    @resume_position = progress&.completed ? 0 : progress&.position_seconds.to_i
    assign_sequence_neighbors
  end

  # GET /playing/:slug/related — lazy Turbo Frame content (US8, FR-028). Inside a
  # collection the sidebar lists the sequence IN ORDER; otherwise same-kind recent.
  def related
    @video = find_playable_video!
    ids = sequence_ids
    if ids.present? && ids.include?(@video.id)
      ordered = ids - [ @video.id ]
      @related = Video.in_order_of(:id, ordered).with_attached_thumbnail.limit(20).to_a
      @sequenced = true
    else
      @related = @video.related(pundit_user, limit: 12)
    end
  end

  private

    # The collection this playback belongs to. Playlists need an explicit ?list=
    # (a video can be in many); a series is auto-derived from the episode, so no
    # param is needed. nil for standalone videos.
    def sequence_collection
      return @sequence_collection if defined?(@sequence_collection)

      @sequence_collection =
        if params[:list].present?
          playlist = Playlist.find_by(id: params[:list])
          playlist if playlist && PlaylistPolicy.new(pundit_user, playlist).show?
        else
          @video.parent_series
        end
    end

    def sequence_ids
      return @sequence_ids if defined?(@sequence_ids)

      @sequence_ids = sequence_collection&.ordered_video_ids(pundit_user)
    end

    def assign_sequence_neighbors
      ids = sequence_ids
      return if ids.blank?

      idx = ids.index(@video.id)
      return if idx.nil?

      @prev_video = Video.with_attached_thumbnail.find_by(id: ids[idx - 1]) if idx.positive?
      @next_video = Video.with_attached_thumbnail.find_by(id: ids[idx + 1]) if idx < ids.length - 1
    end

    # Carried on prev/next/related links so navigation stays within the sequence.
    # Only playlists need it; a series is re-derived from the episode each hop.
    def sequence_params
      sequence_collection.is_a?(Playlist) ? { list: sequence_collection.id } : {}
    end
    helper_method :sequence_params
end
