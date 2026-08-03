module Admin
  # Admin user management: a searchable member list, a detail page summarising
  # each member's activity, and an edit modal that can change what the member
  # can change themselves plus role, email and password.
  #
  # Admin surfaces are deliberately unscoped by VideoPolicy (same as
  # Admin::VideosController): moderation needs to see private and restricted
  # titles, and each row carries a visibility badge so it is never ambiguous.
  class UsersController < AdminController
    include Paginatable
    include ModalLayout

    RECENT_LIMIT = 5
    PAGE_LIMIT = 20

    before_action :set_user, except: :index

    def index
      @query = params[:q].to_s.strip
      scope = User.order(created_at: :desc)
      if @query.present?
        like = "%#{User.sanitize_sql_like(@query)}%"
        scope = scope.where(
          "users.email_address ILIKE :q OR users.display_name ILIKE :q", q: like
        )
      end
      @pagy, @users = paginate(scope.with_attached_avatar, limit: PAGE_LIMIT)
    end

    def show
      @recent_comments  = comments_scope.limit(RECENT_LIMIT)
      @recent_playlists = playlists_scope.limit(RECENT_LIMIT)
      # The recent rails are a glance at the member, not a place to surface
      # their private or restricted titles — those live behind the PIN on the
      # see-all pages.
      @recent_likes   = likes_scope.visibility_public.limit(RECENT_LIMIT)
      @recent_uploads = uploads_scope.visibility_public.limit(RECENT_LIMIT)

      @counts = {
        comments:  @user.comments.count,
        playlists: @user.playlists.count,
        likes:     @user.liked_videos.count,
        uploads:   @user.uploaded_videos.count
      }
    end

    # --- "see all" pages -------------------------------------------------------

    def comments
      @pagy, @comments = paginate(comments_scope, limit: PAGE_LIMIT)
    end

    def playlists
      @pagy, @playlists = paginate(playlists_scope, limit: PAGE_LIMIT)
    end

    def likes
      @pagy, @likes = paginate(pin_gated(likes_scope), limit: PAGE_LIMIT)
    end

    def uploads
      @pagy, @uploads = paginate(pin_gated(uploads_scope), limit: PAGE_LIMIT)
    end

    # --- edit ------------------------------------------------------------------

    def edit; end

    def update
      if @user.update(user_params)
        # Refresh whichever surface opened the modal: the detail card on the
        # show page, or the row on the index. Turbo ignores a missing target.
        render turbo_stream: [
          turbo_stream.replace("admin_user_detail",
                               partial: "admin/users/detail", locals: { user: @user }),
          turbo_stream.replace("admin_user_row_#{@user.id}",
                               partial: "admin/users/row", locals: { item: @user }),
          turbo_stream.update("modal", "")
        ]
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

      def set_user
        @user = User.find(params[:id])
      end

      def comments_scope
        @user.comments.order(created_at: :desc).includes(:video)
      end

      # The detail panels list a few member videos, so preload them: rendering
      # the panel must not cost a query per row.
      def playlists_scope
        @user.playlists.order(created_at: :desc).includes(playlist_items: :video)
      end

      def likes_scope
        detailed(@user.liked_videos.order("likes.created_at DESC"))
      end

      def uploads_scope
        detailed(@user.uploaded_videos.recent)
      end

      # Video rows show like/comment tallies in their detail panel; preloading
      # both keeps that at two queries rather than two per row.
      def detailed(videos)
        videos.with_attached_thumbnail.includes(:likes, :comments)
      end

      # Private, unlisted and restricted titles are listed only once the admin
      # has unlocked with their own PIN. An admin with no PIN can never satisfy
      # pin_unlocked?, so for them those titles simply do not appear — there is
      # no path that reveals them. Sets @locked so the view can say why.
      def pin_gated(scope)
        @locked = !pin_unlocked?
        @pin_set = Current.user.pin?
        @locked ? scope.visibility_public : scope
      end

      def user_params
        permitted = params.require(:user).permit(
          :display_name, :email_address, :role,
          :password, :password_confirmation, :avatar, :cover
        )

        # A blank password field means "leave the password alone" rather than
        # "set an empty password".
        if permitted[:password].blank?
          permitted.delete(:password)
          permitted.delete(:password_confirmation)
        end

        # An admin must not change their own role: demoting or blocking
        # yourself revokes admin access with no way back through the UI.
        permitted.delete(:role) if @user == Current.user

        permitted
      end
  end
end
