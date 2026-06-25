class Tagging < ApplicationRecord
  belongs_to :genre
  belongs_to :taggable, polymorphic: true
end
