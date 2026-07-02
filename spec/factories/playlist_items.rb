FactoryBot.define do
  factory :playlist_item do
    playlist { nil }
    video { nil }
    position { 1 }
  end
end
