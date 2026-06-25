class CreateLikes < ActiveRecord::Migration[8.0]
  def change
    create_table :likes, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :likeable, polymorphic: true, null: false, type: :uuid

      t.timestamps
    end
  end
end
