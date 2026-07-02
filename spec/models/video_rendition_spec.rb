require 'rails_helper'

RSpec.describe VideoRendition, type: :model do
  it "has a valid factory" do
    expect(build(:video_rendition)).to be_valid
  end

  it { is_expected.to belong_to(:video) }
  it { is_expected.to validate_presence_of(:resolution) }

  it "has a file attachment" do
    expect(described_class.reflect_on_attachment(:file)).to be_present
  end
end
