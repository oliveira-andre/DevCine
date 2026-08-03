class VideosController < ApplicationController
  include Paginatable
  include ModalLayout
  include CatalogListing

  # Standalone videos (50/pg) — policy-scoped (restricted only when unlocked),
  # sorted per feature 011 (no genre pills — videos aren't genre-tagged).
  def index
    scope = ordered(policy_scope(Video).standalone.with_attached_thumbnail.with_attached_preview)
    @pagy, @videos = paginate(scope, limit: 50)
  end

  # Standalone video upload form, rendered in the shared modal (US5). One blank
  # subtitle slot is built so the form renders a first row; the uploader can add
  # more, and an untouched slot is discarded on save.
  def new
    @video = Current.user.uploaded_videos.new
    @video.subtitles.build
  end

  # Two ways in.
  #
  # DRAFT (params[:draft]) — the form submitted itself as soon as it had a title
  # and a file, so ffmpeg has something to read. Held private and `uploading`
  # until #update finalises it, so an abandoned draft never reaches a listing
  # (VideoPolicy filters on visibility). The response is the same form in
  # update mode, carrying the lazy frame that fetches the suggestions.
  #
  # DIRECT — the form was submitted outright (no JavaScript, so no autosave).
  # Behaves as it always did: a finished video, no suggestions offered.
  def create
    drafting = params[:draft] == "1"

    @video = Current.user.uploaded_videos.new(video_params)
    @video.kind = :standalone   # forced server-side
    @video.require_file = true
    @video.status = drafting ? :uploading : :ready
    @video.visibility = :private if drafting

    if @video.save
      drafting ? render_draft_step : finish_upload
    else
      @video.subtitles.build if @video.subtitles.empty?
      render :new, status: :unprocessable_entity
    end
  end

  # Finalises the draft: applies the viewer's real visibility, their thumbnail
  # choice, and marks it ready.
  def update
    @video = Current.user.uploaded_videos.friendly.find(params[:id])
    @video.assign_attributes(video_params)
    @video.status = :ready

    if @video.save
      apply_chosen_thumbnail
      finish_upload
    else
      render partial: "videos/modal", locals: { video: @video }, status: :unprocessable_entity
    end
  end

  private

  def render_draft_step
    render turbo_stream: turbo_stream.update(
      "modal", render_to_string(partial: "videos/modal", locals: { video: @video }, formats: :html)
    )
  end

  def finish_upload
    render turbo_stream: [
      turbo_stream.update("modal", ""),
      turbo_stream.prepend("recent_uploads_items", partial: "home/poster_card", locals: { item: @video })
    ]
  end

  # The picked suggestion arrives as a signed blob id; anything else (including
  # nothing picked) just leaves the thumbnail alone. Candidates are cleared
  # either way so they don't linger in storage.
  def apply_chosen_thumbnail
    chosen = params.dig(:video, :thumbnail_signed_id)
    @video.accept_thumbnail_candidate(chosen) if chosen.present?
    @video.clear_thumbnail_candidates!
  end

  def video_params
    params.require(:video).permit(
      :title, :description, :maturity_rating, :visibility, :file, :thumbnail,
      subtitles_attributes: %i[file language]
    )
  end
end
