# Series have no own visibility; while locked, hide only a serie whose videos
# exist and are ALL restricted (mixed series stay listed — their restricted
# episodes are gated at the video level). Feature 006.
class SeriePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if pin_unlocked?

      restricted = Video.visibilities[:restricted]
      scope.where(<<~SQL.squish, restricted: restricted)
        NOT EXISTS (
          SELECT 1 FROM seasons s
          JOIN episodes e ON e.season_id = s.id
          WHERE s.serie_id = series.id
        )
        OR EXISTS (
          SELECT 1 FROM seasons s
          JOIN episodes e ON e.season_id = s.id
          JOIN videos v ON v.id = e.video_id
          WHERE s.serie_id = series.id AND v.visibility <> :restricted
        )
      SQL
    end
  end
end
