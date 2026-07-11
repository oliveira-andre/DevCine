FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}.#{FFaker::Internet.email}" }
    password { "password123" }
    password_confirmation { "password123" }
    display_name { FFaker::Name.name }
    role { :user }

    trait :admin do
      role { :admin }
    end

    trait :blocked do
      role { :blocked }
    end

    trait :with_avatar do
      after(:build) { |user| AttachmentHelpers.attach_sample(user, :avatar, filename: "avatar.jpg") }
    end

    trait :with_cover do
      after(:build) { |user| AttachmentHelpers.attach_sample(user, :cover, filename: "cover.jpg") }
    end
  end
end
