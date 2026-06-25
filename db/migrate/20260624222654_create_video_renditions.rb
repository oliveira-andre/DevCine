class CreateVideoRenditions < ActiveRecord::Migration[8.0]
  def change
    create_table :video_renditions, id: :uuid do |t|
      t.references :video, null: false, foreign_key: true, type: :uuid
      t.string :resolution, null: false
      t.integer :bitrate
      t.integer :format

      t.timestamps
    end
  end
end
