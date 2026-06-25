class CreateEpisodes < ActiveRecord::Migration[8.0]
  def change
    create_table :episodes, id: :uuid do |t|
      t.references :season, null: false, foreign_key: true, type: :uuid
      t.references :video, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text :description
      t.integer :position, null: false
      t.date :release_date

      t.timestamps
    end
  end
end
