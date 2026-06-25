class Person < ApplicationRecord
  has_many :credits, dependent: :destroy
end
