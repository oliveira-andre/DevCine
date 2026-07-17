class AddUniqueIndexToVideoViews < ActiveRecord::Migration[8.0]
  def up
    # Watch history keeps exactly one row per (user, video); recency lives in
    # watched_at. De-dup existing rows (keep the most recent) before the unique
    # index (feature 005, FR-018).
    execute <<~SQL
      DELETE FROM video_views vv
      USING video_views newer
      WHERE vv.user_id = newer.user_id
        AND vv.video_id = newer.video_id
        AND vv.watched_at < newer.watched_at
    SQL
    # Exact watched_at ties: keep the lowest id.
    execute <<~SQL
      DELETE FROM video_views vv
      USING video_views dup
      WHERE vv.user_id = dup.user_id
        AND vv.video_id = dup.video_id
        AND vv.watched_at = dup.watched_at
        AND vv.id > dup.id
    SQL

    add_index :video_views, [ :user_id, :video_id ], unique: true,
              name: "index_video_views_on_user_and_video"
  end

  def down
    remove_index :video_views, name: "index_video_views_on_user_and_video"
  end
end
