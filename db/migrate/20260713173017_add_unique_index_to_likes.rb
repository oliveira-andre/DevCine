class AddUniqueIndexToLikes < ActiveRecord::Migration[8.0]
  def up
    # A user likes a given record at most once — de-dup then enforce (FR-022).
    execute <<~SQL
      DELETE FROM likes l
      USING likes dup
      WHERE l.user_id = dup.user_id
        AND l.likeable_type = dup.likeable_type
        AND l.likeable_id = dup.likeable_id
        AND l.id > dup.id
    SQL

    add_index :likes, [ :user_id, :likeable_type, :likeable_id ], unique: true,
              name: "index_likes_on_user_and_likeable"
  end

  def down
    remove_index :likes, name: "index_likes_on_user_and_likeable"
  end
end
