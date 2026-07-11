FactoryBot.define do
  factory :video_view do
    association :video
    association :user
    watched_at { Time.current }
    ip_hash { SecureRandom.hex(8) }
  end
end
