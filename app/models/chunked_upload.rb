# A resumable upload assembled from small chunks streamed by the browser
# (chunked_upload_controller.js). Each chunk is a short request that beats the
# reverse-proxy's response timeout, so multi-GB video files upload without a 502
# — all while the bytes stay on the local Disk service (no S3).
#
# Chunks are appended, in order, to a per-user scratch file under tmp/. The
# first chunk truncates (a fresh upload reusing an id must not tack onto stale
# bytes); the rest append. Once every chunk has arrived, the completed file is
# handed to the upload action as a normal UploadedFile and then discarded.
#
# Not an ActiveRecord model — just a value object over a tmp file path. It lives
# in app/models so it autoloads and reads as a first-class domain concept.
class ChunkedUpload
  ROOT = Rails.root.join("tmp", "chunked_uploads")
  # crypto.randomUUID() — the only shape the id may take, so a forged value can
  # never escape the per-user directory via "../".
  ID_FORMAT = /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/

  class InvalidId < StandardError; end

  def self.dir_for(user)
    ROOT.join(user&.id&.to_s || "anonymous")
  end

  def initialize(user, id)
    @user = user
    @id = id.to_s
    raise InvalidId, "invalid upload id" unless @id.match?(ID_FORMAT)
  end

  def path
    self.class.dir_for(@user).join(@id)
  end

  # Append one chunk. `first` truncates so a reused id starts clean.
  def append(io, first:)
    FileUtils.mkdir_p(path.dirname)
    File.open(path, first ? "wb" : "ab") { |dest| IO.copy_stream(io, dest) }
  end

  def exists?
    File.exist?(path)
  end

  # An Active Storage attachable for the assembled bytes — `file.attach(...)`
  # takes this hash exactly like it takes a multipart `params[:file]`, streaming
  # the scratch file straight into the Disk service without loading it in memory.
  def to_attachable(filename:, content_type:)
    return nil unless exists?

    {
      io: File.open(path, "rb"),
      filename: filename.presence || "upload",
      content_type: content_type.presence || "application/octet-stream"
    }
  end

  # Best-effort cleanup once the bytes have been copied into Active Storage.
  def discard
    File.delete(path) if exists?
  rescue SystemCallError
    nil
  end
end
