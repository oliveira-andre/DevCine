class CreateMovies < ActiveRecord::Migration[8.0]
  def change
    create_table :movies, id: :uuid do |t|
      t.references :video, null: false, foreign_key: true, type: :uuid
      t.references :trailer, null: true, foreign_key: { to_table: :videos }, type: :uuid
      t.string :title, null: false
      t.string :original_title
      t.text :description
      t.date :release_date
      t.string :backdrop_key
      t.integer :maturity_rating, default: 0

      t.timestamps
    end
  end
end
