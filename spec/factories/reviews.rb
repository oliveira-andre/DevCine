FactoryBot.define do
  factory :review do
    user { nil }
    reviewable { nil }
    rating { 1 }
    title { "MyString" }
    body { "MyText" }
  end
end
