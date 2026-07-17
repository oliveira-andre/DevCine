class AddMissingIndexes < ActiveRecord::Migration[8.0]
  def up
    # Every listing filters visibility_public and sorts by created_at; related and
    # kind browse filter by kind. These were unindexed (2026-07 audit).
    add_index :videos, [ :visibility, :created_at ]
    add_index :videos, [ :kind, :visibility ]

    # One resume position per (user, video) — required for the upsert in
    # WatchProgress.record!. De-dup first (keep the most recently updated).
    execute <<~SQL
      DELETE FROM watch_progresses wp
      USING watch_progresses newer
      WHERE wp.user_id = newer.user_id
        AND wp.video_id = newer.video_id
        AND (wp.updated_at < newer.updated_at
             OR (wp.updated_at = newer.updated_at AND wp.id > newer.id))
    SQL
    add_index :watch_progresses, [ :user_id, :video_id ], unique: true,
              name: "index_watch_progresses_on_user_and_video"

    # A video appears in a playlist at most once (like-sync and the add-to-playlist
    # toggle both guard in Ruby, but the DB allowed duplicates).
    execute <<~SQL
      DELETE FROM playlist_items pi
      USING playlist_items dup
      WHERE pi.playlist_id = dup.playlist_id
        AND pi.video_id = dup.video_id
        AND pi.id > dup.id
    SQL
    add_index :playlist_items, [ :playlist_id, :video_id ], unique: true,
              name: "index_playlist_items_on_playlist_and_video"
  end

  def down
    remove_index :videos, [ :visibility, :created_at ]
    remove_index :videos, [ :kind, :visibility ]
    remove_index :watch_progresses, name: "index_watch_progresses_on_user_and_video"
    remove_index :playlist_items, name: "index_playlist_items_on_playlist_and_video"
  end
end
