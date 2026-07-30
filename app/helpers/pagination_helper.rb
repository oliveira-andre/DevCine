module PaginationHelper
  # URL for the next page on the CURRENT route (used by section listing pages
  # rendered by their own controller). Returns nil at the last page.
  def next_page_url(pagy)
    # Preserve the current query string (e.g. genre/sort from feature 011) so the
    # lazy next-page frame stays filtered and sorted.
    url_for(request.query_parameters.merge(page: pagy.next)) if pagy&.next
  end
end
