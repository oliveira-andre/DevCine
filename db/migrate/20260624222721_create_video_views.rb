class CreateVideoViews < ActiveRecord::Migration[8.0]
  def change
    create_table :video_views, id: :uuid do |t|
      t.references :video, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.datetime :watched_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.string :ip_hash

      t.timestamps
    end
  end
end
