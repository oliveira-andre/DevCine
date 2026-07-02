class CreateSeries < ActiveRecord::Migration[8.0]
  def change
    create_table :series, id: :uuid do |t|
      t.string :title, null: false
      t.text :description
      t.date :release_date
      t.string :slug
      t.integer :status, default: 0
      t.integer :maturity_rating, default: 0

      t.timestamps
    end

    add_index :series, :slug, unique: true
  end
end
