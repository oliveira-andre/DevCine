module PaginationHelper
  # URL for the next page on the CURRENT route (used by section listing pages
  # rendered by their own controller). Returns nil at the last page.
  def next_page_url(pagy)
    url_for(page: pagy.next) if pagy&.next
  end
end
