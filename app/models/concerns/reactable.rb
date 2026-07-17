# Like/dislike helpers for anything with polymorphic `likes` (Video, Comment).
# Loaded-aware: when the association is eager-loaded (comments thread), counts
# and lookups run in memory instead of issuing per-record queries.
module Reactable
  def likes_count
    if likes.loaded?
      likes.count(&:reaction_like?)
    else
      likes.reaction_like.count
    end
  end

  def dislikes_count
    if likes.loaded?
      likes.count(&:reaction_dislike?)
    else
      likes.reaction_dislike.count
    end
  end

  # The given user's reaction ("like" / "dislike") on this record, or nil.
  def reaction_by(user)
    return nil unless user

    if likes.loaded?
      likes.detect { |like| like.user_id == user.id }&.kind
    else
      likes.find_by(user: user)&.kind
    end
  end
end
