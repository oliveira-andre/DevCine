require 'rails_helper'

RSpec.describe Ordering, type: :model do
  describe "validations" do
    it "requires label, field, direction" do
      expect(Ordering.new).to be_invalid
    end

    it "only allows allowlisted fields and directions" do
      expect(Ordering.new(label: "X", field: "drop table", direction: "asc")).to be_invalid
      expect(Ordering.new(label: "X", field: "title", direction: "sideways")).to be_invalid
      expect(Ordering.new(label: "X", field: "title", direction: "asc")).to be_valid
    end

    it "slugifies the label" do
      expect(Ordering.create!(label: "A-Z", field: "title", direction: "asc").slug).to eq("a-z")
    end
  end

  describe "single default (FR-011)" do
    it "unsets other defaults when one is set" do
      a = Ordering.create!(label: "A-Z", field: "title", direction: "asc", default: true)
      b = Ordering.create!(label: "Z-A", field: "title", direction: "desc", default: true)
      expect(a.reload.default).to be(false)
      expect(b.reload.default).to be(true)
    end
  end

  describe ".options / .resolve" do
    let!(:older) { Ordering.create!(label: "Most older", field: "created_at", direction: "asc", position: 1) }
    let!(:az)    { Ordering.create!(label: "A-Z", field: "title", direction: "asc", position: 2) }

    before { Ordering.bump_version(Ordering::CACHE_SCOPE) }

    it "options begins with the non-record most-recent default" do
      opts = Ordering.options
      expect(opts.first).to eq(Ordering::MOST_RECENT)
      expect(opts.first.record?).to be(false)
      expect(opts.map(&:label)).to eq(["most recent", "Most older", "A-Z"])
    end

    it "resolves a known slug to its record" do
      expect(Ordering.resolve("a-z")).to eq(az)
    end

    it "resolves 'most-recent', unknown, and blank-without-default to most recent" do
      expect(Ordering.resolve("most-recent")).to eq(Ordering::MOST_RECENT)
      expect(Ordering.resolve("bogus")).to eq(Ordering::MOST_RECENT)
      expect(Ordering.resolve(nil)).to eq(Ordering::MOST_RECENT)
    end

    it "resolves blank to the default record when one exists" do
      az.update!(default: true)
      Ordering.bump_version(Ordering::CACHE_SCOPE)
      expect(Ordering.resolve(nil)).to eq(az)
    end
  end

  describe "#order_sql (safe, qualified, tiebroken)" do
    it "qualifies columns with the table and case-folds title" do
      az = Ordering.new(label: "A-Z", field: "title", direction: "asc")
      expect(az.order_sql("movies")).to eq("LOWER(movies.title) ASC, movies.id ASC")
    end

    it "orders by created_at for the created_at field" do
      older = Ordering.new(label: "Most older", field: "created_at", direction: "asc")
      expect(older.order_sql("series")).to eq("series.created_at ASC, series.id ASC")
    end

    it "most-recent default is newest first with a tiebreak" do
      expect(Ordering::MOST_RECENT.order_sql("videos")).to eq("videos.created_at DESC, videos.id DESC")
    end
  end

  describe "#sort_array (in-memory)" do
    Item = Struct.new(:title, :created_at)

    it "sorts by title ascending / descending" do
      items = [Item.new("Banana", 1), Item.new("apple", 2), Item.new("Cherry", 3)]
      az = Ordering.new(label: "A-Z", field: "title", direction: "asc")
      za = Ordering.new(label: "Z-A", field: "title", direction: "desc")
      expect(az.sort_array(items).map(&:title)).to eq(["apple", "Banana", "Cherry"])
      expect(za.sort_array(items).map(&:title)).to eq(["Cherry", "Banana", "apple"])
    end
  end
end
