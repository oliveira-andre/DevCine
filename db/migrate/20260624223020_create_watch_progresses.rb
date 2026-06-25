class CreateWatchProgresses < ActiveRecord::Migration[8.0]
  def change
    create_table :watch_progresses, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :video, null: false, foreign_key: true, type: :uuid
      t.integer :position_seconds
      t.boolean :completed

      t.timestamps
    end
  end
end
