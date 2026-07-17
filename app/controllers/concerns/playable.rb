# Resolves a video by slug and authorizes it through VideoPolicy#watch? —
# THE single record-level visibility gate (feature 006, FR-017). Shared by the
# player, comments, view/progress recording, reactions, and playlist additions.
module Playable
  extend ActiveSupport::Concern

  private

  # The slug→id lookup stays cached (Constitution VI; busted by
  # Video#bust_player_caches). Pass a scope to eager-load attachments.
  def find_playable_video!(slug = params[:slug], scope: Video)
    id = Rails.cache.fetch([ "video", slug ]) { Video.friendly.find(slug).id }
    video = scope.find(id)
    authorize video, :watch?, policy_class: VideoPolicy
    video
  end
end
