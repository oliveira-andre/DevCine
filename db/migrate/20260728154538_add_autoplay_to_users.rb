class AddAutoplayToUsers < ActiveRecord::Migration[8.0]
  def change
    # Per-user autoplay preference (feature 010). Default ON: a finished video
    # auto-advances to the next unless the user turns it off.
    add_column :users, :autoplay, :boolean, null: false, default: true
  end
end
