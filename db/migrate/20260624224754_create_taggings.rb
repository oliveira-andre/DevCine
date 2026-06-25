class CreateTaggings < ActiveRecord::Migration[8.0]
  def change
    create_table :taggings, id: :uuid do |t|
      t.references :genre, null: false, foreign_key: true, type: :uuid
      t.references :taggable, polymorphic: true, null: false, type: :uuid

      t.timestamps
    end
  end
end
