# Playlist visibility (feature 007). Playlists carry a visibility enum but had no
# policy until non-owners could reach one via the show page. public/unlisted are
# viewable by any signed-in user; private is owner-only. NotAuthorizedError maps
# to 404 app-wide (feature 006) — no existence disclosure.
class PlaylistPolicy < ApplicationPolicy
  def show?
    return true if record.visibility_public? || record.visibility_unlisted?

    viewer.present? && record.user_id == viewer.id
  end

  # Owner-only, and never the auto-managed "Videos you liked" playlist.
  def destroy?
    viewer.present? && record.user_id == viewer.id && !record.system?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if viewer.nil?

      scope.where(visibility: %i[public unlisted]).or(scope.where(user_id: viewer.id))
    end
  end
end
