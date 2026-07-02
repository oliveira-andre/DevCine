FactoryBot.define do
  factory :serie do
    sequence(:title) { |n| "#{FFaker::Movie.title} #{n}" }
    description { FFaker::Lorem.paragraph }
    release_date { FFaker::Time.date }
    status { :ongoing }
    maturity_rating { 1 }

    trait :with_poster do
      after(:build) { |serie| AttachmentHelpers.attach_sample(serie, :poster, filename: "poster.jpg") }
    end

    trait :with_backdrop do
      after(:build) { |serie| AttachmentHelpers.attach_sample(serie, :backdrop, filename: "backdrop.jpg") }
    end
  end
end
