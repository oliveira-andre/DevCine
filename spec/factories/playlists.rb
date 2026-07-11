FactoryBot.define do
  factory :playlist do
    association :user
    sequence(:title) { |n| "#{FFaker::Book.title} Mix #{n}" }
    visibility { :public }

    trait :private_list do
      visibility { :private }
    end

    trait :with_videos do
      transient { videos_count { 3 } }
      after(:create) do |playlist, ctx|
        create_list(:playlist_item, ctx.videos_count, playlist: playlist)
      end
    end
  end
end
