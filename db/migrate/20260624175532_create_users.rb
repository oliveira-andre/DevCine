class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :uuid do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :handle, default: -> { "gen_random_uuid()" }, null: false
      t.string :display_name
      t.string :pin_digest
      t.date :birthdate
      t.datetime :email_confirmed_at

      t.timestamps
    end

    add_index :users, :email_address, unique: true
    add_index :users, :handle, unique: true
  end
end
