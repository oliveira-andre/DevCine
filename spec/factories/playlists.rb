FactoryBot.define do
  factory :playlist do
    user { nil }
    title { "MyString" }
    visibility { 1 }
  end
end
