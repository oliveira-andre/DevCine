class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :video, null: false, foreign_key: true, type: :uuid
      t.references :parent, foreign_key: { to_table: :comments }, type: :uuid, null: true
      t.text :body, null: false

      t.timestamps
    end
  end
end
