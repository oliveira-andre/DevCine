require 'rails_helper'

RSpec.describe VideoPolicy do
  let(:owner) { create(:user) }
  let(:other) { create(:user) }

  def context(user, unlocked: false)
    AuthContext.new(user: user, pin_unlocked: unlocked)
  end

  def watch?(video, user, unlocked: false)
    described_class.new(context(user, unlocked: unlocked), video).watch?
  end

  describe "#watch?" do
    it "allows anyone for public and unlisted" do
      expect(watch?(create(:video, visibility: :public), other)).to be(true)
      expect(watch?(create(:video, visibility: :unlisted), other)).to be(true)
    end

    it "allows only the owner for private (unlock is irrelevant)" do
      video = create(:video, visibility: :private, uploader: owner)
      expect(watch?(video, owner)).to be(true)
      expect(watch?(video, other)).to be(false)
      expect(watch?(video, other, unlocked: true)).to be(false)
      expect(watch?(video, nil)).to be(false)
    end

    it "allows restricted only while unlocked — uniformly, even for the uploader" do
      video = create(:video, visibility: :restricted, maturity_rating: :A18, uploader: owner)
      expect(watch?(video, other)).to be(false)
      expect(watch?(video, owner)).to be(false)
      expect(watch?(video, other, unlocked: true)).to be(true)
      expect(watch?(video, owner, unlocked: true)).to be(true)
    end
  end

  describe "Scope#resolve" do
    let!(:public_video) { create(:video, visibility: :public) }
    let!(:unlisted_video) { create(:video, visibility: :unlisted) }
    let!(:private_video) { create(:video, visibility: :private, uploader: owner) }
    let!(:restricted_video) { create(:video, visibility: :restricted, maturity_rating: :A18) }

    it "lists only public while locked" do
      result = described_class::Scope.new(context(other), Video).resolve
      expect(result).to contain_exactly(public_video)
    end

    it "adds restricted while unlocked (never private/unlisted)" do
      result = described_class::Scope.new(context(other, unlocked: true), Video).resolve
      expect(result).to contain_exactly(public_video, restricted_video)
    end
  end

  describe "Scope#resolve_owned (owner's own uploads relation)" do
    it "shows the owner's private/unlisted but keeps restricted PIN-gated" do
      mine_private = create(:video, visibility: :private, uploader: owner)
      mine_unlisted = create(:video, visibility: :unlisted, uploader: owner)
      mine_public = create(:video, visibility: :public, uploader: owner)
      mine_restricted = create(:video, visibility: :restricted, maturity_rating: :A18, uploader: owner)

      locked = described_class::Scope.new(context(owner), owner.uploaded_videos).resolve_owned
      expect(locked).to contain_exactly(mine_private, mine_unlisted, mine_public)

      unlocked = described_class::Scope.new(context(owner, unlocked: true), owner.uploaded_videos).resolve_owned
      expect(unlocked).to contain_exactly(mine_private, mine_unlisted, mine_public, mine_restricted)
    end
  end
end
