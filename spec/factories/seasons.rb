FactoryBot.define do
  factory :season do
    serie { nil }
    name { "MyString" }
    description { "MyText" }
    position { 1 }
    release_date { "2026-06-24" }
  end
end
