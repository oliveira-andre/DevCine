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
    @album = album_label
    # Subtitle tracks for file-based videos only (feature 012).
    @subtitle_tracks = @video.embed? ? [] : @video.subtitle_tracks
  end

  # GET /playing/:slug/related — lazy Turbo Frame content (US8, FR-028). Inside a
  # collection the sidebar CONTINUES the sequence from the playing video — on
  # E22 it lists E23, E24, E25… (earlier episodes wrap after), never the start
  # of the serie, so up-next is always the first card. Otherwise same-kind recent.
  def related
    @video = find_playable_video!
    ids = sequence_ids
    if ids.present? && (idx = ids.index(@video.id))
      ordered = ids[(idx + 1)..] + ids[0...idx]
      @related = ordered.empty? ? [] : Video.in_order_of(:id, ordered).with_attached_thumbnail.limit(20).to_a
      @sequenced = true
    else
      @related = @video.related(pundit_user, limit: 12)
    end
  end

  # GET /playing/:slug/up_next — the descriptor for the video autoplay should
  # advance to (feature 010, US5). Precedence: serie/playlist next → first
  # "more like this" recommendation not already in the played chain. Returns 204
  # when nothing eligible remains so the client stops autoplay.
  def up_next
    @video = find_playable_video!
    played = params[:played].to_s.split(",").map(&:strip).reject(&:blank?)

    nxt, keep_list = resolve_next(played)
    return head :no_content unless nxt

    render json: next_descriptor(nxt, keep_list)
  end

  private

    # [next_video, keep_playlist_context?] or [nil, false].
    def resolve_next(played)
      ids = sequence_ids
      if ids.present? && (idx = ids.index(@video.id)) && idx < ids.length - 1
        candidate = playable_load(ids[idx + 1])
        return [ candidate, sequence_collection.is_a?(Playlist) ] if candidate
      end

      # Recommendation fallback (category + tag match), skipping the played chain.
      @video.related(pundit_user, limit: 20).each do |rel|
        next if played.include?(rel.slug)
        candidate = playable_load(rel.id)
        return [ candidate, false ] if candidate
      end
      [ nil, false ]
    end

    # A video is autoplay-eligible only if it is a real file (not a live embed)
    # and visible to the viewer (the sources above already scope visibility).
    def playable_load(id)
      video = Video.with_attached_file.with_attached_thumbnail.find_by(id: id)
      video if video&.file&.attached? && !video.embed?
    end

    def next_descriptor(video, keep_list)
      list = keep_list ? params[:list] : nil
      prev_v, next_v = neighbors_for(video, list)
      progress = WatchProgress.find_by(user: Current.user, video: video)
      resume = progress&.completed ? 0 : progress&.position_seconds.to_i
      params_for = list.present? ? { list: list } : {}

      {
        slug: video.slug,
        # Redirect mode (disk controller = Rack::Files) — the proxy cannot serve
        # a full-file byte range for multi-GB videos (see player/show.html.erb).
        # rails_storage_redirect_path, not rails_blob_path: the latter resolves
        # back to the proxy via resolve_model_to_route.
        src: rails_storage_redirect_path(video.file),
        artwork: video.thumbnail.attached? ? rails_storage_proxy_path(video.thumbnail) : "/logo.png",
        title: video.display_title,
        album: album_for(video, list),
        prevUrl: prev_v ? player_path(prev_v.slug, params_for) : "",
        nextUrl: next_v ? player_path(next_v.slug, params_for) : "",
        resume: resume,
        list: list,
        viewsUrl: views_player_path(video.slug),
        progressUrl: progress_player_path(video.slug),
        upNextUrl: up_next_player_path(video.slug, params_for),
        # Subtitle tracks + the viewer's caption prefs ride along so an
        # IN-PLACE advance (fullscreen / docked autoplay, no page navigation)
        # keeps captions working on the next episode.
        subtitles: helpers.subtitle_tracks_data(video, video.subtitle_tracks),
        subEnabled: Current.user.subtitles_enabled,
        subTextColor: Current.user.subtitle_text_color,
        subBgColor: Current.user.subtitle_background_color,
        subFontSize: Current.user.subtitle_font_size,
        subFontWeight: Current.user.subtitle_font_weight
      }
    end

    # Neighbors of an arbitrary video within its collection (serie auto-derived,
    # or the given playlist). Mirrors assign_sequence_neighbors for the next hop.
    def neighbors_for(video, list)
      coll = collection_for(video, list)
      ids = coll&.ordered_video_ids(pundit_user)
      return [ nil, nil ] if ids.blank?

      idx = ids.index(video.id)
      return [ nil, nil ] if idx.nil?

      prev_v = idx.positive? ? Video.with_attached_thumbnail.find_by(id: ids[idx - 1]) : nil
      next_v = idx < ids.length - 1 ? Video.with_attached_thumbnail.find_by(id: ids[idx + 1]) : nil
      [ prev_v, next_v ]
    end

    def collection_for(video, list)
      if list.present?
        playlist = Playlist.find_by(id: list)
        playlist if playlist && PlaylistPolicy.new(pundit_user, playlist).show?
      else
        video.parent_series
      end
    end

    def album_for(video, list)
      coll = collection_for(video, list)
      coll ? coll.title : "DevCine"
    end

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

    # Media Session "album" (feature 010): the serie name when playing an episode,
    # the playlist name when played from a playlist, else the site name.
    def album_label
      case sequence_collection
      when Serie, Playlist then sequence_collection.title
      else "DevCine"
      end
    end

    # Carried on prev/next/related links so navigation stays within the sequence.
    # Only playlists need it; a series is re-derived from the episode each hop.
    def sequence_params
      sequence_collection.is_a?(Playlist) ? { list: sequence_collection.id } : {}
    end
    helper_method :sequence_params
end
