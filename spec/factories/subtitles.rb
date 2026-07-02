FactoryBot.define do
  factory :subtitle do
    association :video
    language { 1 }
    is_default { false }

    trait :with_file do
      after(:build) { |subtitle| AttachmentHelpers.attach_sample(subtitle, :file, filename: "subtitle.vtt") }
    end
  end
end
