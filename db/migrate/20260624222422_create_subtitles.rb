class CreateSubtitles < ActiveRecord::Migration[8.0]
  def change
    create_table :subtitles, id: :uuid do |t|
      t.references :video, null: false, foreign_key: true, type: :uuid
      t.integer :language, null: false
      t.boolean :is_default, default: false

      t.timestamps
    end
  end
end
