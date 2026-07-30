module CatalogControlsHelper
  # Build a URL for the CURRENT listing route with the given params overridden
  # (feature 011). Preserves path params (e.g. genre-browse :slug, :kind) and the
  # current query string (e.g. search :q), drops `page` (filter/sort resets to
  # page 1), and removes any override set to nil (used to clear a filter).
  def listing_url(**overrides)
    base = request.path_parameters.symbolize_keys
                  .merge(request.query_parameters.except("page").symbolize_keys)
                  .merge(overrides)
                  .reject { |_, value| value.nil? }
    url_for(base)
  end
end
