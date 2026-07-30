# Shared genre-filter + ordering behavior for catalog listing pages (feature
# 011). Include it in a listing controller and wrap the base scope:
#
#   @pagy, @movies = paginate(ordered(by_genre(policy_scope(Movie)...)))
#
# `ordered`/`ordered_array` apply the resolved ?sort= (defaulting to the app's
# "most recent"); `by_genre` applies the resolved ?genre= (movies/series only).
module CatalogListing
  extend ActiveSupport::Concern

  included do
    helper_method :current_ordering, :catalog_orderings, :active_genre, :catalog_genres
  end

  private

  # The resolved ordering option (a record or the "most recent" system default).
  def current_ordering
    @current_ordering ||= Ordering.resolve(params[:sort])
  end

  # The full option list for the sort pill.
  def catalog_orderings
    Ordering.options
  end

  # Apply the current ordering to an ActiveRecord relation (safe, allowlisted).
  def ordered(relation)
    relation.reorder(Arel.sql(current_ordering.order_sql(relation.table_name)))
  end

  # Apply the current ordering to an in-memory array (the combined genre browse).
  def ordered_array(array)
    current_ordering.sort_array(array)
  end

  # The active genre filter (movies/series), or nil. Unknown slug → nil (ignored).
  def active_genre
    return @active_genre if defined?(@active_genre)
    @active_genre = params[:genre].present? ? Genre.find_by(slug: params[:genre]) : nil
  end

  # Filter a taggable relation by the active genre (no-op when none).
  def by_genre(relation)
    return relation unless active_genre
    relation.joins(:taggings).where(taggings: { genre_id: active_genre.id })
  end

  # Genre pills (cached).
  def catalog_genres
    Genre.pill_list
  end
end
