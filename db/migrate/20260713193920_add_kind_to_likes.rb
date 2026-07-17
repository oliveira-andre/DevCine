class AddKindToLikes < ActiveRecord::Migration[8.0]
  def change
    # A "like" row is now a reaction: 0 = like (up), 1 = dislike (down).
    # Existing rows are likes (feature 005 enhancement).
    add_column :likes, :kind, :integer, default: 0, null: false
  end
end
