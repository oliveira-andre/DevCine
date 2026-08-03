require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#breakable_label" do
    it "adds a wrap opportunity after a slash" do
      expect(helper.breakable_label("Action/Adventure"))
        .to eq("Action/<wbr>Adventure")
    end

    it "leaves a name without a slash untouched" do
      expect(helper.breakable_label("Documentary")).to eq("Documentary")
    end

    it "handles several slashes" do
      expect(helper.breakable_label("A/B/C")).to eq("A/<wbr>B/<wbr>C")
    end

    it "escapes html so admin-authored names cannot inject markup" do
      result = helper.breakable_label("<script>x</script>/B")

      expect(result).to include("&lt;script&gt;")
      expect(result).not_to include("<script>")
      # <wbr> is the only tag the helper is allowed to emit.
      expect(result.scan(/<[^>]+>/).uniq).to eq([ "<wbr>" ])
    end

    it "returns a blank string for nil" do
      expect(helper.breakable_label(nil)).to eq("")
    end
  end
end
