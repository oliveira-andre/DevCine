# Pagy configuration (installed version: 43.6.0).
#
# --- Verified API for this version (spike, tasks T004) ---
# Controllers include Pagy::Method and call:
#     @pagy, @records = pagy(:offset, scope, limit: 20)
# The current page is read from params[:page] / the request automatically.
#   @pagy.page  => current page (Integer)
#   @pagy.next  => next page number, or nil at the last page
#   @pagy.last  => last page number
#   @pagy.limit => per-page size
# The next-page URL is built manually in views: url_for(page: @pagy.next).
# An out-of-range page raises Pagy::RangeError (handled by the Paginatable concern).

Pagy::OPTIONS[:limit] = 20        # default page size
Pagy::OPTIONS[:max_limit] = 100   # allow larger explicit limits (e.g. 50 for standalone videos)
