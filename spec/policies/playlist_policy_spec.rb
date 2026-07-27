require 'rails_helper'

RSpec.describe PlaylistPolicy do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }

  def ctx(user)
    AuthContext.new(user: user, pin_unlocked: false)
  end

  def show?(playlist, user)
    described_class.new(ctx(user), playlist).show?
  end

  describe "#show?" do
    it "allows any signed-in viewer for public and unlisted" do
      expect(show?(create(:playlist, user: owner, visibility: :public), other)).to be(true)
      expect(show?(create(:playlist, user: owner, visibility: :unlisted), other)).to be(true)
    end

    it "allows only the owner for a private playlist" do
      private_list = create(:playlist, user: owner, visibility: :private)
      expect(show?(private_list, owner)).to be(true)
      expect(show?(private_list, other)).to be(false)
      expect(show?(private_list, nil)).to be(false)
    end
  end

  describe "#destroy?" do
    def destroy?(playlist, user)
      described_class.new(ctx(user), playlist).destroy?
    end

    it "allows only the owner" do
      list = create(:playlist, user: owner, title: "Mine")
      expect(destroy?(list, owner)).to be(true)
      expect(destroy?(list, other)).to be(false)
      expect(destroy?(list, nil)).to be(false)
    end

    it "forbids deleting the auto 'Videos you liked' playlist" do
      liked = owner.liked_playlist
      expect(destroy?(liked, owner)).to be(false)
    end
  end

  describe "Scope#resolve" do
    it "returns public/unlisted plus the viewer's own private lists" do
      pub = create(:playlist, user: other, visibility: :public)
      unl = create(:playlist, user: other, visibility: :unlisted)
      mine_private = create(:playlist, user: owner, visibility: :private)
      others_private = create(:playlist, user: other, visibility: :private)

      resolved = described_class::Scope.new(ctx(owner), Playlist).resolve
      expect(resolved).to include(pub, unl, mine_private)
      expect(resolved).not_to include(others_private)
    end
  end
end
