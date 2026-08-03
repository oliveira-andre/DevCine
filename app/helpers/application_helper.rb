module ApplicationHelper
  # Allows a label to wrap after "/". UAX #14 gives no break opportunity at a
  # solidus, so "Action/Adventure" is a single token wider than a search chip
  # and would otherwise break mid-word. <wbr> adds the opportunity without
  # putting a character into the text content. Escapes input — names are
  # admin-authored.
  def breakable_label(text)
    safe_join(text.to_s.split(%r{(?<=/)}), tag.wbr)
  end
end
