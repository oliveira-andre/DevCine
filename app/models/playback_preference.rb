# A viewer's remembered audio track + subtitle language for one TITLE — the
# Serie for episodes (all episodes follow it), the Movie for features, the
# Video itself for standalones. Exactly one row per (user, title): the unique
# index backs it, so a change UPDATES the row rather than piling up new ones.
#
# The audio choice is stored by track NAME (AudioTrack rows are per-video, so
# ids don't carry across a serie's episodes); each video resolves the name
# against its own tracks at load time and falls back to its default when the
# name doesn't exist there.
class PlaybackPreference < ApplicationRecord
  belongs_to :user
  belongs_to :watchable, polymorphic: true

  validates :watchable_type, inclusion: { in: %w[Serie Movie Video] }
  validates :user_id, uniqueness: { scope: %i[watchable_type watchable_id] }
end
