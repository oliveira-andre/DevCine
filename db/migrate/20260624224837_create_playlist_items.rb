class CreatePlaylistItems < ActiveRecord::Migration[8.0]
  def change
    create_table :playlist_items, id: :uuid do |t|
      t.references :playlist, null: false, foreign_key: true, type: :uuid
      t.references :video, null: false, foreign_key: true, type: :uuid
      t.integer :position, null: false

      t.timestamps
    end
  end
end
