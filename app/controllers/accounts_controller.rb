class AccountsController < ApplicationController
  RAIL_LIMIT = 20

  # Own profile (/account) or a public profile (/account/:slug by handle).
  # Owner sees actions + their own private/unlisted uploads + History; a
  # non-owner sees public content only. Restricted titles follow the PIN gate
  # uniformly (feature 006): hidden everywhere until unlocked, owner included.
  def show
    @user = params[:slug].present? ? User.find_by!(handle: params[:slug]) : Current.user
    @owner = @user == Current.user

    @recent_uploads = uploads_scope(@user.uploaded_videos.recent)
                        .with_attached_thumbnail.with_attached_preview.limit(RAIL_LIMIT)
    @likes = policy_scope(@user.liked_videos.recent).with_attached_thumbnail.limit(RAIL_LIMIT)

    playlists = @user.playlists.order(created_at: :desc)
    playlists = playlists.visibility_public unless @owner
    @playlists = playlists.includes(:playlist_items).limit(RAIL_LIMIT)

    @history =
      if @owner
        @user.video_views.joins(:video).merge(policy_scope(Video))
             .order(watched_at: :desc)
             .includes(video: [ :thumbnail_attachment, :preview_attachment ]).limit(RAIL_LIMIT)
      end
  end

  private

  # Owner sees their own private/unlisted uploads (restricted still PIN-gated);
  # everyone else gets the plain policy scope.
  def uploads_scope(video_relation)
    if @owner
      VideoPolicy::Scope.new(pundit_user, video_relation).resolve_owned
    else
      policy_scope(video_relation)
    end
  end
end
