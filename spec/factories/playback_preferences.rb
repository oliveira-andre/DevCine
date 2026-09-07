FactoryBot.define do
  factory :playback_preference do
    association :user
    association :watchable, factory: :serie
    audio_track_name { "English" }
    subtitle_language { nil }
  end
end
