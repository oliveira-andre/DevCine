FactoryBot.define do
  factory :movie do
    association :video
    trailer { nil }
    sequence(:title) { |n| "#{FFaker::Movie.title} #{n}" }
    original_title { FFaker::Movie.title }
    description { FFaker::Lorem.paragraph }
    release_date { FFaker::Time.date }
    backdrop_key { nil }
    maturity_rating { 1 }

    trait :with_poster do
      after(:build) { |movie| AttachmentHelpers.attach_sample(movie, :poster, filename: "poster.jpg") }
    end

    trait :with_backdrop do
      after(:build) { |movie| AttachmentHelpers.attach_sample(movie, :backdrop, filename: "backdrop.jpg") }
    end

    trait :with_backdrop_key do
      backdrop_key { FFaker::Internet.http_url }
    end
  end
end
