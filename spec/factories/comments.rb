FactoryBot.define do
  factory :comment do
    association :user
    association :video
    body { FFaker::Lorem.sentence }
  end
end
