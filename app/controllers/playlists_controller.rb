class PlaylistsController < ApplicationController
  include Paginatable
  include Playable
  include ModalLayout
  include CatalogListing

  # GET /playlists — browse public playlists, with an optional ?q= title filter.
  # `discoverable` is public-only: unlisted playlists stay reachable by link but
  # are never listed.
  def index
    @query = params[:q].to_s.strip
    scope = Playlist.discoverable.includes(:user, :playlist_items)
    if @query.present?
      scope = scope.where("playlists.title ILIKE ?", "%#{Playlist.sanitize_sql_like(@query)}%")
    end
    @pagy, @playlists = paginate(ordered(scope), limit: 20)
  end

  # GET /playlists/:id — the playlist show page (feature 007). Flat ordered list;
  # no seasons. private → owner only (else 404 via Pundit).
  def show
    @playlist = Playlist.find(params[:id])
    authorize @playlist, :show?
    # Drives the save button: owners have nothing to save, and a second save
    # would just return the copy they already have.
    @owned = @playlist.user_id == Current.user&.id
    @saved_copy = @playlist.clone_for(Current.user)
    @current_video = @playlist.current_video(Current.user, pundit_user)
    @hero_video = @current_video || @playlist.first_video(pundit_user)
    @play_target = @playlist.play_target(Current.user, pundit_user)
    ids = @playlist.ordered_video_ids(pundit_user)
    @pagy, @videos = paginate(Video.in_order_of(:id, ids).with_attached_thumbnail, limit: 12)
    @next_url = @pagy&.next ? playlist_path(@playlist, page: @pagy.next) : nil
  end

  # GET /playlists/new — the account-page create modal (feature 008, US2).
  def new
    @playlist = Playlist.new
  end

  # DELETE /playlists/:id — remove a playlist (feature 008 delete). Owner-only;
  # the auto "Videos you liked" list is protected. dependent: :destroy removes
  # the join rows (memberships) but never the videos themselves. One response
  # removes the element from whichever surface it lives on (player popover row or
  # account card).
  def destroy
    @playlist = Playlist.find(params[:id])
    authorize @playlist, :destroy?
    @playlist.destroy

    render turbo_stream: [
      turbo_stream.remove("playlist_row_#{@playlist.id}"),
      turbo_stream.remove("playlist_card_#{@playlist.id}")
    ]
  end

  # POST /playlists — create a playlist under the current user (feature 008).
  # Two contexts: from the player add-to-playlist popover (a video `slug` is
  # present → US1) or from the account modal (no slug → US2).
  def create
    @playlist = Current.user.playlists.new(title: playlist_params[:title], visibility: :public)

    if params[:slug].present?
      create_from_player
    else
      create_from_account
    end
  end

  private

    def playlist_params
      params.require(:playlist).permit(:title)
    end

    # US1: append the new toggle row for the current video + reset the inline
    # "Add a playlist" control. On failure re-render the inline form with errors.
    def create_from_player
      @video = find_playable_video! # enforce visibility (no IDOR on private videos)

      if @playlist.save
        render turbo_stream: [
          turbo_stream.append("playlist-add-list",
                              partial: "playlist_additions/row", locals: { playlist: @playlist, video: @video }),
          turbo_stream.replace("playlist-add-create",
                               partial: "playlist_additions/create_row", locals: { video: @video })
        ]
      else
        render turbo_stream: turbo_stream.replace("playlist-add-create",
          partial: "playlist_additions/create_row", locals: { video: @video, playlist: @playlist, open: true }),
          status: :unprocessable_entity
      end
    end

    # US2: append the new card to the account rail + close the modal. On failure
    # re-render the modal with errors.
    def create_from_account
      if @playlist.save
        render turbo_stream: [
          turbo_stream.append("account_playlists",
                              partial: "accounts/playlist_card", locals: { playlist: @playlist, owner: true }),
          turbo_stream.update("modal", "") # close the shared modal
        ]
      else
        render :new, status: :unprocessable_entity
      end
    end
end
