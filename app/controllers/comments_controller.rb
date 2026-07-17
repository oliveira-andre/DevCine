class CommentsController < ApplicationController
  include Playable
  include Paginatable

  # GET /playing/:slug/comments — the lazy comments Turbo Frame content (US7,
  # FR-028). Newest-first, paginated for infinite scroll.
  def index
    @video = find_playable_video!
    @pagy, @comments = paginate(
      Comment.for_video(@video).includes(:user, :likes, replies: [ :user, :likes ]),
      limit: 20
    )
  end

  # POST /playing/:slug/comments — post a comment (signed-in). Turbo-Stream
  # prepends it and resets the form; blank body re-renders the form with a 422.
  def create
    @video = find_playable_video!
    @comment = @video.comments.build(
      user: Current.user, body: comment_params[:body], parent_id: comment_params[:parent_id]
    )

    if @comment.save
      # renders create.turbo_stream.erb
    else
      form_id = @comment.reply? ? "reply_form_#{@comment.parent_id}" : "comment_form"
      render turbo_stream: turbo_stream.replace(
        form_id,
        partial: "comments/form",
        locals: { video: @video, comment: @comment, form_id: form_id,
                  placeholder: (@comment.reply? ? "Add a reply…" : "Add a comment…"),
                  submit_label: (@comment.reply? ? "Reply" : "Comment") }
      ), status: :unprocessable_entity
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end
end
