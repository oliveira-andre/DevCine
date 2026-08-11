# Receives one chunk of a resumable upload for the MEMBER upload form (the
# /account "Upload video" modal) and appends it to the caller's scratch file
# (see ChunkedUpload). The client sends chunks in order; videos#create later
# assembles + attaches them. Requires only a signed-in member — the scratch is
# scoped per user and only becomes a video when the upload action accepts it.
# (The admin catalog slots use their own admin-gated twin under /admin.)
class ChunkedUploadsController < ApplicationController
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
