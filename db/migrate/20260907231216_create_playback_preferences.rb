class CreatePlaybackPreferences < ActiveRecord::Migration[8.0]
  # One playback preference (audio track + subtitle language) per user per
  # TITLE — the Serie for episodes, the Movie for features, the Video itself
  # for standalones. The unique index is what guarantees update-not-create.
  def change
    create_table :playback_preferences, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :user_id, null: false
      t.string :watchable_type, null: false
      t.uuid :watchable_id, null: false
      t.string :audio_track_name
      t.string :subtitle_language

      t.timestamps
    end
    add_index :playback_preferences, [ :user_id, :watchable_type, :watchable_id ],
              unique: true, name: "index_playback_preferences_uniqueness"
    add_foreign_key :playback_preferences, :users
  end
end
