class CreateGenres < ActiveRecord::Migration[8.0]
  def change
    create_table :genres, id: :uuid do |t|
      t.string :name
      t.string :slug

      t.timestamps
    end
    add_index :genres, :slug, unique: true
  end
end
