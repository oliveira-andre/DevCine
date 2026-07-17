# The single visibility authority for videos (feature 006, FR-017). Replaces
# the old Video#playable_by? and Video.listable.
class VideoPolicy < ApplicationPolicy
  # Can the viewer watch this video (player page, media data, comments,
  # views/progress recording, reactions, playlist add)?
  def watch?
    if record.visibility_public? || record.visibility_unlisted?
      true
    elsif record.visibility_restricted?
      pin_unlocked?
    else # private: owner only — "he uploads, he sees it"
      viewer.present? && record.uploader_id == viewer.id
    end
  end

  class Scope < ApplicationPolicy::Scope
    # Every listing surface: public always; restricted only while unlocked.
    def resolve
      scope.where(visibility: visible_visibilities)
    end

    # Owner variant for the account page's own-profile rails. ONLY call this on
    # a relation already filtered to the owner's uploads: it additionally shows
    # private/unlisted (the owner's own), while restricted stays PIN-gated even
    # for the uploader (uniform rule).
    def resolve_owned
      scope.where(visibility: visible_visibilities + [ :private, :unlisted ])
    end

    private

    def visible_visibilities
      pin_unlocked? ? [ :public, :restricted ] : [ :public ]
    end
  end
end
