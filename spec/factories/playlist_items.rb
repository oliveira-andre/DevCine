FactoryBot.define do
  factory :playlist_item do
    association :playlist
    association :video
    sequence(:position) { |n| n }
  end
end
