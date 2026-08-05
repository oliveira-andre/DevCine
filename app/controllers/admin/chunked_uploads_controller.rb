module Admin
  # Receives one chunk of a resumable upload and appends it to the caller's
  # scratch file (see ChunkedUpload). The client sends chunks in order; the
  # matching upload action later assembles + attaches them. Admin-only: the
  # only chunked uploads today are catalog video slots.
  class ChunkedUploadsController < AdminController
    # Each chunk is its own tiny request — the CSRF meta token is sent in a
    # header by the fetch() in chunked_upload_controller.js.
    def create
      upload = ChunkedUpload.new(Current.user, params[:upload_id])
      upload.append(params[:chunk].to_io, first: params[:index].to_i.zero?)
      head :ok
    rescue ChunkedUpload::InvalidId
      head :bad_request
    end
  end
end
