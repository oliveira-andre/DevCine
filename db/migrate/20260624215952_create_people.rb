class CreatePeople < ActiveRecord::Migration[8.0]
  def change
    create_table :people, id: :uuid do |t|
      t.string :name, null: false
      t.text :biography
      t.date :birthdate

      t.timestamps
    end
  end
end
