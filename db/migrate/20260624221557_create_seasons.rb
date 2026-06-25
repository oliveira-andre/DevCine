class CreateSeasons < ActiveRecord::Migration[8.0]
  def change
    create_table :seasons, id: :uuid do |t|
      t.references :serie, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description
      t.integer :position, null: false
      t.date :release_date

      t.timestamps
    end
  end
end
