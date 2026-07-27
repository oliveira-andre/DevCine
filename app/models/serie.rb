class Serie < ApplicationRecord
  extend FriendlyId
  extend Cacheable
  include Collection
  friendly_id :title, use: :slugged

  enum :status, {
    ongoing: 0,
    ended: 1
  }

  enum :maturity_rating, {
    L: 0,
    A6: 1,
    A10: 2,
    A12: 3,
    A14: 4,
    A16: 5,
    A18: 6
  }

  has_many :seasons, dependent: :destroy
  has_many :videos, through: :seasons

  has_many :credits, as: :creditable, dependent: :destroy
  has_many :reviews, as: :reviewable, dependent: :destroy
  has_many :watchlist_items, as: :watchlistable, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy

  has_many :people, through: :credits, source: :person
  has_many :genres, through: :taggings, source: :taggable, source_type: "Genre"

  # Media (Active Storage): card poster + optional backdrop (not used by the hero).
  has_one_attached :poster
  has_one_attached :backdrop

  validates :title, presence: true

  # Recency for the "Recently added series" rail.
  scope :recent, -> { order(created_at: :desc) }

  # Seasons in display order (carousel + default-season pick).
  def ordered_seasons
    seasons.order(:position)
  end

  # All member video ids in canonical order: season.position → episode.position.
  # Collection#ordered_video_ids filters these to the visible set + caches.
  def raw_ordered_video_ids
    Episode.joins(:season).where(seasons: { serie_id: id })
           .order(Arel.sql("seasons.position ASC, episodes.position ASC"))
           .pluck(:video_id)
  end

  # Visible video ids for ONE season (paginated by the controller). Cached under
  # the serie's order version so a season/episode/video change invalidates it.
  def season_video_ids(season, auth_context)
    version = self.class.cache_version(order_cache_scope)
    self.class.cache_read([ "season-order", id, season.id, auth_context.pin_unlocked, version ]) do
      raw = season.episodes.order(:position).pluck(:video_id)
      next [] if raw.empty?

      visible = VideoPolicy::Scope.new(auth_context, Video.where(id: raw)).resolve.pluck(:id).to_set
      raw.select { |vid| visible.include?(vid) }
    end
  end

  # Bump the order version on any change to the serie itself (Constitution VI);
  # season/episode/video changes bump the same scope from their own callbacks.
  after_commit { Serie.bump_version(order_cache_scope) }
end
