require 'rails_helper'

RSpec.describe Person, type: :model do
  it "has a valid factory" do
    expect(build(:person)).to be_valid
  end

  it "has a photo attachment" do
    expect(described_class.reflect_on_attachment(:photo)).to be_present
  end
end
