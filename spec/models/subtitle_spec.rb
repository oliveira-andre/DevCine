require 'rails_helper'

RSpec.describe Subtitle, type: :model do
  it "has a valid factory" do
    expect(build(:subtitle)).to be_valid
  end

  it { is_expected.to belong_to(:video) }

  it "has a file attachment" do
    expect(described_class.reflect_on_attachment(:file)).to be_present
  end
end
