class ReactionsController < ApplicationController
  include ActionView::RecordIdentifier

  REACTABLES = { "video" => Video, "comment" => Comment }.freeze

  # POST /reactions/:type/:id — toggle the current user's like/dislike on a
  # video or comment. Turbo-Stream replaces just the reaction buttons.
  def create
    @record = find_reactable
    toggle_reaction(@record, reaction_kind)

    render turbo_stream: turbo_stream.replace(
      dom_id(@record, :reactions),
      partial: "reactions/reactions", locals: { record: @record }
    )
  end

  private

  def find_reactable
    klass = REACTABLES.fetch(params[:type]) { raise ActiveRecord::RecordNotFound }
    record = klass.find(params[:id])
    # Enforce video visibility via the policy; comments inherit their video's access.
    video = record.is_a?(Video) ? record : record.video
    authorize video, :watch?, policy_class: VideoPolicy

    record
  end

  def reaction_kind
    params[:kind].to_s.presence_in(%w[like dislike]) || "like"
  end

  def toggle_reaction(record, kind)
    existing = record.likes.find_by(user: Current.user)
    if existing.nil?
      record.likes.create!(user: Current.user, kind: kind)
    elsif existing.kind == kind
      existing.destroy # toggle off
    else
      existing.update!(kind: kind) # switch like <-> dislike
    end
  end
end
