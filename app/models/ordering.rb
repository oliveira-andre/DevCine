class Ordering < ApplicationRecord
  extend FriendlyId
  extend Cacheable
  friendly_id :label, use: :slugged

  FIELDS = %w[created_at title].freeze
  DIRECTIONS = %w[asc desc].freeze
  MOST_RECENT_SLUG = "most-recent".freeze
  CACHE_SCOPE = [ "orderings" ].freeze

  validates :label, :field, :direction, presence: true
  validates :field, inclusion: { in: FIELDS }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :slug, uniqueness: true, allow_nil: true

  # At most one row is the default (FR-011).
  before_save :unset_other_defaults, if: -> { default? && will_save_change_to_default? }
  after_commit { Ordering.bump_version(CACHE_SCOPE) }

  scope :ordered, -> { order(:position, :created_at) }

  # True for persisted options; the system default overrides this to false.
  def record? = true

  # The built-in "most recent" default — NOT a persisted row (FR-009). Responds
  # to the same interface as an Ordering record so callers treat them uniformly.
  class SystemDefault
    def slug = MOST_RECENT_SLUG
    def label = "most recent"
    def record? = false
    def default? = false

    # Newest first, with a stable tiebreak. Columns are qualified with the
    # relation's table so the ORDER BY isn't ambiguous when it joins (e.g. a
    # movie query joined to videos — both carry created_at/id).
    def order_sql(table = nil)
      q = table ? "#{table}." : ""
      "#{q}created_at DESC, #{q}id DESC"
    end

    def sort_array(array) = array.sort_by(&:created_at).reverse
  end
  MOST_RECENT = SystemDefault.new

  # --- options / resolution --------------------------------------------------

  # The full pill list: the system default plus every configured record.
  def self.options
    [ MOST_RECENT ] + records
  end

  # Cached record list (Constitution VI), invalidated on any Ordering write.
  def self.records
    cache_read([ "orderings", "records", cache_version(CACHE_SCOPE) ]) { ordered.to_a }
  end

  def self.default_record
    records.find(&:default?)
  end

  # Resolve a ?sort= param to an option. Precedence (contracts/listing.md):
  # explicit known slug → that record; "most-recent"/unknown → most recent;
  # blank → the default record, else most recent.
  def self.resolve(param)
    param = param.to_s
    return MOST_RECENT if param == MOST_RECENT_SLUG
    if param.present?
      records.find { |o| o.slug == param } || MOST_RECENT
    else
      default_record || MOST_RECENT
    end
  end

  # --- applying the ordering --------------------------------------------------

  # Safe ORDER BY with a stable id tiebreak so offset pagination doesn't skip or
  # duplicate. field/direction come from an allowlist, never interpolated raw.
  # Columns are qualified with the relation's table so the ORDER BY isn't
  # ambiguous when the query joins another table that shares the column name.
  def order_sql(table = nil)
    q = table ? "#{table}." : ""
    column = field == "title" ? "LOWER(#{q}title)" : "#{q}created_at"
    dir = direction == "desc" ? "DESC" : "ASC"
    "#{column} #{dir}, #{q}id ASC"
  end

  # In-memory equivalent for the one combined list (catalog genre browse).
  def sort_array(array)
    key = field == "title" ? ->(x) { x.title.to_s.downcase } : ->(x) { x.created_at }
    sorted = array.sort_by(&key)
    direction == "desc" ? sorted.reverse : sorted
  end

  private

  def unset_other_defaults
    Ordering.where.not(id: id).update_all(default: false)
  end
end
