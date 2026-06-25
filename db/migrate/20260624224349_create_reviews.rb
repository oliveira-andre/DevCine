class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :reviewable, polymorphic: true, null: false, type: :uuid
      t.integer :rating, null: false
      t.string :title, null: false
      t.text :body

      t.timestamps
    end
  end
end
