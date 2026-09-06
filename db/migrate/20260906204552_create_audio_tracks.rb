class CreateAudioTracks < ActiveRecord::Migration[8.0]
  # Named audio tracks per video (MKV ingest). The default track's sound is
  # embedded in the playable MP4 itself; alternates carry extracted .m4a files
  # (Active Storage) awaiting the HLS audio-switching milestone.
  def change
    create_table :audio_tracks, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid :video_id, null: false
      t.string :name, null: false
      t.string :language
      t.integer :position, null: false, default: 1

      t.timestamps
    end
    add_index :audio_tracks, [ :video_id, :position ]
    add_foreign_key :audio_tracks, :videos
  end
end
