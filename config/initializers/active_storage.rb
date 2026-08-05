# How media is served (all local Disk, no object storage):
#
# - Small assets (posters, thumbnails, ~15s hover previews) go through the
#   proxy (config.active_storage.resolve_model_to_route = :rails_storage_proxy)
#   — cacheable, and comfortably inside the proxy's default 100 MB range cap.
#
# - The player's video source uses REDIRECT mode (rails_storage_redirect_path;
#   note rails_blob_path resolves back to the proxy via resolve_model_to_route):
#   a <video> element opens with `Range: bytes=0-` (the entire file), and the
#   proxy both rejects a range larger than `streaming_chunk_max_size` with a
#   416 AND buffers the whole requested range in memory before sending. The
#   redirect path lands on ActiveStorage::DiskController, which serves byte
#   ranges of any size via Rack::Files at constant memory — the only way a
#   multi-GB movie can play from local Disk. Do not switch the player back to
#   rails_storage_proxy_path, and do not "fix" a playback 416 by raising
#   streaming_chunk_max_size: past ~1 GB that trades the 416 for Puma
#   swallowing the file size in RAM per viewer.
