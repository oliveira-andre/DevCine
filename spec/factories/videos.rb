FactoryBot.define do
  factory :video do
    sequence(:title) { |n| "#{FFaker::Movie.title} #{n}" }
    description { FFaker::Lorem.paragraph }
    duration_seconds { rand(60..7200) }
    status { :ready }
    visibility { :public }
    kind { :standalone }
    view_count { rand(0..10_000) }
    file_size_bytes { rand(1_000_000..2_000_000_000) }
    published_at { Time.current }
    association :uploader, factory: :user

    trait :with_thumbnail do
      after(:build) { |video| AttachmentHelpers.attach_sample(video, :thumbnail, filename: "thumb.jpg") }
    end

    # Live videos play via an embed URL, not a file (feature 009).
    trait :live do
      kind { :live }
      live_embed_url { "https://www.youtube.com/embed/O8bnDdWsk8Q" }
    end

    trait :with_file do
      after(:build) { |video| AttachmentHelpers.attach_sample(video, :file, filename: "clip.mp4") }
    end
  end
end
