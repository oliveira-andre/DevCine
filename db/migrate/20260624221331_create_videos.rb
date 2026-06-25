class CreateVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :videos, id: :uuid do |t|
      t.string :title, null: false
      t.text :description
      t.integer :duration_seconds, null: false
      t.integer :status, default: 0
      t.integer :visibility, default: 0
      t.integer :kind, default: 0
      t.bigint :view_count, default: 0
      t.bigint :file_size_bytes, default: 0
      t.datetime :published_at, default: -> { "CURRENT_TIMESTAMP" }
      t.references :uploader, foreign_key: { to_table: :users }, type: :uuid, null: false

      t.timestamps
    end
  end
end
