# The ffmpeg-suggested frames for a draft upload.
#
# #show is fetched by a lazy Turbo Frame on the upload form, so the extraction
# happens in its own request: the form renders immediately with a spinner and
# Turbo swaps in the frames when they're ready. Nothing here is driven by
# hand-written JavaScript.
#
# The admin catalog upload has no "before save" moment (dropping the file is
# the save), so it still redirects here as a full page after the fact.
class ThumbnailSuggestionsController < ApplicationController
  include ModalLayout

  before_action :set_video

  def show
    # Extract on first look. Doing it here rather than during the upload is what
    # keeps the form responsive — this request is the one that waits.
    @video.suggest_thumbnails! unless @video.thumbnail_candidates.attached?
  end

  # Used by the admin page flow, where the choice is its own submit rather than
  # a field on a larger form.
  def update
    if @video.accept_thumbnail_candidate(params[:signed_id])
      finish "Thumbnail set."
    else
      redirect_to thumbnail_suggestions_video_path(@video, return_to: params[:return_to]),
                  alert: "That suggestion is no longer available — pick another."
    end
  end

  # Decline the suggestions and keep the video as it is.
  def destroy
    @video.clear_thumbnail_candidates!
    finish "Upload finished without a thumbnail."
  end

  private

    def set_video
      # Videos are FriendlyId-slugged, so the member routes carry a slug.
      @video = Video.friendly.find(params[:id])
      # Only the uploader (or an admin) may dress up a video.
      return if Current.user&.admin? || @video.uploader_id == Current.user&.id

      raise ActiveRecord::RecordNotFound
    end

    def finish(notice)
      # Crossing back to a different page, so force a real navigation rather
      # than a #page-content swap that would leave the URL behind.
      flash[:_full_render] = true
      redirect_to return_path, notice: notice
    end

    # Admin uploads pass where to go back to; account uploads fall back to the
    # uploader's own account page, where the new upload is listed.
    def return_path
      allowed_return_to || account_path
    end

    # Only ever return to a path on this app — never an absolute URL from the
    # query string, which would make this an open redirect.
    #
    # Checking for a leading "//" is not enough. Browsers normalise "\" to "/",
    # so "/\evil.com" becomes protocol-relative and leaves the site, and a
    # leading control character ("/\tevil.com") gets stripped to the same
    # effect. Rails' raise_on_open_redirects does not catch either: Ruby parses
    # both as host-less relative paths, so they look local server-side and only
    # turn external once the browser has them.
    def allowed_return_to
      candidate = params[:return_to].to_s
      return nil unless candidate.start_with?("/")
      return nil if candidate.match?(%r{\A/[/\\]}) || candidate.match?(/[[:cntrl:]]/)

      uri = URI.parse(candidate)
      candidate if uri.scheme.nil? && uri.host.nil?
    rescue URI::InvalidURIError
      nil
    end
end
