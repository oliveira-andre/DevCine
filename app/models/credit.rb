class Credit < ApplicationRecord
  enum :role, {
    director: 0,
    writer: 1,
    producer: 2,
    actor: 3,
    voice: 4,
    extra: 5
  }

  belongs_to :person
  belongs_to :creditable, polymorphic: true
end
