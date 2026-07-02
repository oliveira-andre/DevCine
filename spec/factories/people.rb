FactoryBot.define do
  factory :person do
    name { FFaker::Name.name }
    biography { FFaker::Lorem.paragraph }
    birthdate { FFaker::Time.date }

    trait :with_photo do
      after(:build) { |person| AttachmentHelpers.attach_sample(person, :photo, filename: "photo.jpg") }
    end
  end
end
