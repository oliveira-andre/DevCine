FactoryBot.define do
  factory :video_rendition do
    association :video
    resolution { %w[1080p 720p 480p].sample }
    bitrate { rand(1_000..8_000) }
    format { :mp4 }

    trait :with_file do
      after(:build) { |rendition| AttachmentHelpers.attach_sample(rendition, :file, filename: "rendition.mp4") }
    end
  end
end
