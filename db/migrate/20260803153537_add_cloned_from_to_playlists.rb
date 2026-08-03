class AddClonedFromToPlaylists < ActiveRecord::Migration[8.0]
  def change
    # Where a saved playlist came from. Lets the save button show an
    # already-saved state and keeps a double-click from piling up copies.
    # on_delete: :nullify — losing the original must not delete somebody's copy.
    add_reference :playlists, :cloned_from, type: :uuid, null: true,
                  foreign_key: { to_table: :playlists, on_delete: :nullify }

    # One save per (user, source) — the uniqueness the controller relies on.
    add_index :playlists, [ :user_id, :cloned_from_id ], unique: true,
              where: "cloned_from_id IS NOT NULL",
              name: "index_playlists_on_user_and_cloned_from"
  end
end
