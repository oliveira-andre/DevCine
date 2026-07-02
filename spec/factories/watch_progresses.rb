FactoryBot.define do
  factory :watch_progress do
    association :user
    association :video
    position_seconds { rand(0..3600) }
    completed { false }
  end
end
