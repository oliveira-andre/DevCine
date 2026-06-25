class WatchlistItem < ApplicationRecord
  belongs_to :user
  belongs_to :watchable, polymorphic: true
end
