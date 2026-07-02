FactoryBot.define do
  factory :episode do
    season { nil }
    video { nil }
    title { "MyString" }
    description { "MyText" }
    position { 1 }
    release_date { "2026-06-24" }
  end
end
