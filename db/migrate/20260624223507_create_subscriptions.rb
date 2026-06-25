class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions, id: :uuid do |t|
      t.references :subscriber, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.references :channel, null: false, foreign_key: { to_table: :users }, type: :uuid

      t.timestamps
    end
  end
end
