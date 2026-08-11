module Admin
  # Receives one chunk of a resumable upload and appends it to the caller's
  # scratch file (see ChunkedUpload). The client sends chunks in order; the
  # matching upload action later assembles + attaches them. Admin-only: this
  # endpoint feeds the catalog video slots. (The member upload form has its own
  # member-gated twin: ChunkedUploadsController.)
  class ChunkedUploadsController < AdminController
    # Each chunk is its own tiny request — the CSRF meta token is sent in a
    # header by the fetch() in lib/chunk_uploader.js.
    def create
      upload = ChunkedUpload.new(Current.user, params[:upload_id])
      upload.append(params[:chunk].to_io, first: params[:index].to_i.zero?)
      head :ok
    rescue ChunkedUpload::InvalidId
      head :bad_request
    end
  end
end
