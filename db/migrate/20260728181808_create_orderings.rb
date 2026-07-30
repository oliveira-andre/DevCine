class CreateOrderings < ActiveRecord::Migration[8.0]
  def change
    # Configurable sort options for catalog listings (feature 011). "most recent"
    # is NOT a row here — it is the built-in system default.
    create_table :orderings, id: :uuid do |t|
      t.string  :label, null: false
      t.string  :slug, null: false
      t.string  :field, null: false      # allowlist: created_at | title
      t.string  :direction, null: false  # asc | desc
      t.boolean :default, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :orderings, :slug, unique: true
    add_index :orderings, :position
  end
end
