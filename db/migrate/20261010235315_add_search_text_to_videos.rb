class AddSearchTextToVideos < ActiveRecord::Migration[8.0]
  # Fuzzy title search (pg_trgm). Each video keeps one lowercase string of every
  # title it can be found by — its own, its serie's and its movie's
  # (Video#build_search_text, queried by Video.search). Playlists are searched on
  # their own title instead (Playlist.search): a video can sit in any number of
  # playlists, so their titles would grow a video's string without bound.
  def change
    enable_extension "pg_trgm"
    add_column :videos, :search_text, :text
    add_index :videos, :search_text, using: :gin, opclass: :gin_trgm_ops
    add_index :playlists, :title, using: :gin, opclass: :gin_trgm_ops

    # Fill existing rows so search works right after the deploy's db:prepare.
    up_only do
      Video.reset_column_information
      Video.find_each(&:refresh_search_text!)
    end
  end
end
