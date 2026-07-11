FactoryBot.define do
  factory :like do
    association :user
    association :likeable, factory: :video
  end
end
