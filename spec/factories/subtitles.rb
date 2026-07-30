FactoryBot.define do
  factory :subtitle do
    association :video
    language { :english }
    is_default { false }

    # A real, minimal SRT (feature 012): comma-separated ms so to_vtt conversion
    # is exercised; .srt filename so validation passes.
    trait :with_file do
      after(:build) do |subtitle|
        srt = "1\n00:00:01,000 --> 00:00:04,000\nHello world\n\n" \
              "2\n00:00:05,000 --> 00:00:08,000\nSecond line\n"
        subtitle.file.attach(
          io: StringIO.new(srt), filename: "captions.srt", content_type: "application/x-subrip"
        )
      end
    end
  end
end
