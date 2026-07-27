FactoryBot.define do
  factory :episode do
    association :season
    association :video
    sequence(:title) { |n| "Episode #{n}" }
    description { "MyText" }
    sequence(:position) { |n| n }
    release_date { "2026-06-24" }
  end
end
