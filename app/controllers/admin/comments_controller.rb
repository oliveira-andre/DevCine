module Admin
  # Comment moderation: a searchable, filterable list across every video, a
  # detail view with the full thread context, and delete (which cascades to a
  # top-level comment's replies via the model's dependent: :destroy).
  class CommentsController < AdminController
    include Paginatable

    PAGE_LIMIT = 20

    def index
      @query = params[:q].to_s.strip
      @pagy, @comments = paginate(filtered_scope, limit: PAGE_LIMIT)
    end

    def show
      @comment = Comment.includes(:user, :video, replies: :user).find(params[:id])
    end

    def destroy
      @comment = Comment.find(params[:id])
      @comment.destroy

      # From the list, drop the row in place. From the detail page there is no
      # row to drop, so it asks to be sent back to the list (a 302 the Turbo
      # form submission follows as a full visit).
      if params[:back_to_index]
        # The Turbo form submission carries a turbo-stream Accept onto the
        # redirect, which the app's stream-nav would swap into #page-content
        # without advancing the URL. Force a full render (as sessions/clones do)
        # and 303 so the submission follows it as a GET.
        flash[:_full_render] = true
        redirect_to admin_comments_path, notice: "Comment deleted.", status: :see_other
      else
        render turbo_stream: turbo_stream.remove("admin_comment_row_#{@comment.id}")
      end
    end

    private

      def filtered_scope
        scope = Comment.includes(:user, :video)
        scope = apply_search(scope)
        scope = apply_type(scope)
        scope = apply_video(scope)
        order_scope(scope)
      end

      def apply_search(scope)
        return scope if @query.blank?

        like = "%#{Comment.sanitize_sql_like(@query)}%"
        scope.joins(:user).where(
          "comments.body ILIKE :q OR users.email_address ILIKE :q OR users.display_name ILIKE :q",
          q: like
        )
      end

      # top-level threads vs. replies.
      def apply_type(scope)
        case params[:type]
        when "threads" then scope.where(parent_id: nil)
        when "replies" then scope.where.not(parent_id: nil)
        else scope
        end
      end

      # Optional focus on one video's comments (linked from the video detail).
      def apply_video(scope)
        params[:video_id].present? ? scope.where(video_id: params[:video_id]) : scope
      end

      def order_scope(scope)
        case params[:sort]
        when "oldest" then scope.order(created_at: :asc)
        else scope.order(created_at: :desc)
        end
      end
  end
end
