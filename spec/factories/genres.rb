FactoryBot.define do
  factory :genre do
    # Unique per build so the name-uniqueness validation (feature 013) doesn't
    # trip when a spec creates several; the slug is derived by friendly_id.
    sequence(:name) { |n| "Genre #{n}" }
  end
end
