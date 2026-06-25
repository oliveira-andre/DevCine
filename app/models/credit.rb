class Credit < ApplicationRecord
  belongs_to :person
  belongs_to :creditable, polymorphic: true
end
