FactoryBot.define do
  factory :comment do
    user { nil }
    video { nil }
    parent_id { "" }
    body { "MyText" }
  end
end
