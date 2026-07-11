class AccountsController < ApplicationController
  RAIL_LIMIT = 20

  # Own profile (/account) or a public profile (/account/:slug by handle).
  # Owner sees actions + all content + History; a non-owner visitor sees no
  # actions, public content only, and no History (US2 / US7).
  def show
    @user = params[:slug].present? ? User.find_by!(handle: params[:slug]) : Current.user
    @owner = @user == Current.user

    @recent_uploads = public_scope(@user.uploaded_videos.recent)
                        .with_attached_thumbnail.with_attached_preview.limit(RAIL_LIMIT)
    @likes = public_scope(@user.liked_videos.recent).with_attached_thumbnail.limit(RAIL_LIMIT)

    playlists = @user.playlists.order(created_at: :desc)
    playlists = playlists.visibility_public unless @owner
    @playlists = playlists.includes(:playlist_items).limit(RAIL_LIMIT)

    @history =
      if @owner
        @user.video_views.order(watched_at: :desc)
             .includes(video: [ :thumbnail_attachment, :preview_attachment ]).limit(RAIL_LIMIT)
      end
  end

  private

  # Public-only unless the current user owns the profile.
  def public_scope(video_relation)
    @owner ? video_relation : video_relation.listable
  end
end
