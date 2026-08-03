FactoryBot.define do
  factory :tagging do
    association :genre
    association :taggable, factory: :movie
  end
end
