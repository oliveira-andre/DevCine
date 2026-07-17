# Shared Rails.cache helpers (Constitution VI). Every model read goes through
# Rails.cache with version-aware keys; writes bump an integer version counter so
# dependent keys invalidate without delete_matched (unsupported on some stores).
#
# Usage: `extend Cacheable` in a model, then:
#   Video.cache_read(["related", kind, page, Video.cache_version(["videos", kind])]) { ... }
#   Video.bump_version(["videos", kind])   # in an after_commit
module Cacheable
  # Read-through cache; the block computes the value on a miss.
  def cache_read(key, expires_in: nil, &block)
    Rails.cache.fetch(key, expires_in: expires_in, &block)
  end

  # Current integer version for a logical scope (0 if never bumped).
  def cache_version(scope)
    Rails.cache.read(version_key(scope)).to_i
  end

  # Invalidate everything keyed by this scope's version.
  def bump_version(scope)
    Rails.cache.write(version_key(scope), cache_version(scope) + 1)
  end

  def version_key(scope)
    [ "cache-version", *Array(scope) ]
  end
end
