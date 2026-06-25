class CreateCredits < ActiveRecord::Migration[8.0]
  def change
    create_table :credits, id: :uuid do |t|
      t.references :person, null: false, foreign_key: true, type: :uuid
      t.references :creditable, polymorphic: true, null: false, type: :uuid
      t.integer :role
      t.string :character_name
      t.integer :billing_order

      t.timestamps
    end
  end
end
