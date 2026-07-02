FactoryBot.define do
  factory :credit do
    person { nil }
    creditable { nil }
    role { 1 }
    character_name { "MyString" }
    billing_order { 1 }
  end
end
