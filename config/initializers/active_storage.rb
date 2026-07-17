# Active Storage proxy range limit.
#
# The proxy (config.active_storage.resolve_model_to_route = :rails_storage_proxy)
# serves a single Range response only if it is smaller than
# `streaming_chunk_max_size` — otherwise ActiveStorage::Streaming#ranges_valid?
# returns false and the request gets a 416. A <video> element opens with
# `Range: bytes=0-` (the entire file), so any media larger than the cap fails to
# play through the proxy. The default cap is 100 MB; our seeded sample clip is
# ~435 MB, so raise it for local streaming.
#
# NOTE: an over-cap single range is buffered in memory before being sent, so in
# production prefer a CDN in front of the proxy (it caches and serves byte ranges)
# and reasonably sized / transcoded media rather than raising this much further.
# Must set the config option (ActiveStorage applies it in an after_initialize,
# overwriting any direct assignment to ActiveStorage.streaming_chunk_max_size).
Rails.application.config.active_storage.streaming_chunk_max_size = 500.megabytes
