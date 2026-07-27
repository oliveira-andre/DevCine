FactoryBot.define do
  factory :season do
    association :serie
    sequence(:name) { |n| "Season #{n}" }
    description { "MyText" }
    sequence(:position) { |n| n }
    release_date { "2026-06-24" }
  end
end
