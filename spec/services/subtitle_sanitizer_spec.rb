require "rails_helper"

# SRT text cleaner (MKV ingest): ffmpeg's ASS→SRT conversion leaves HTML tags
# and {\an8} overrides in the cue text — strip to plain words, keep timing.
RSpec.describe SubtitleSanitizer do
  it "strips HTML tags and ASS overrides, keeping the timing untouched" do
    dirty = <<~SRT
      1
      00:00:46,440 --> 00:00:48,540
      <font face="RH Sans" size="78">My head hurts.</font>

      2
      00:01:15,610 --> 00:01:17,830
      <font face="AltonaBold" size="200" color="#55b835"><b>{\\an8}<font size="45">Stomach
      Medicine</font></b></font>
    SRT

    clean = described_class.call(dirty)

    expect(clean).to eq(<<~SRT)
      1
      00:00:46,440 --> 00:00:48,540
      My head hurts.

      2
      00:01:15,610 --> 00:01:17,830
      Stomach
      Medicine
    SRT
  end

  it "drops cues left with no text (pure styling/karaoke effects) and renumbers" do
    dirty = <<~SRT
      1
      00:02:13,440 --> 00:02:13,440
      <font face="Advert-Bold" size="75" color="#000000"><b>{\\an8}<font color="#50aa31"></font></b></font>

      2
      00:02:13,440 --> 00:02:13,610
      <b>{\\an8}chu</b>
    SRT

    clean = described_class.call(dirty)

    expect(clean).to eq("1\n00:02:13,440 --> 00:02:13,610\nchu\n")
  end

  it "leaves an already-clean SRT unchanged" do
    plain = "1\n00:00:01,000 --> 00:00:04,000\nHello there\n\n2\n00:00:05,000 --> 00:00:06,000\nSecond line\n"
    expect(described_class.call(plain)).to eq(plain)
  end

  it "handles CRLF line endings, a BOM, and HTML entities" do
    dirty = "\u{FEFF}1\r\n00:00:01,000 --> 00:00:02,000\r\n<i>Tom &amp; Jerry</i>\r\n"
    expect(described_class.call(dirty)).to eq("1\n00:00:01,000 --> 00:00:02,000\nTom & Jerry\n")
  end

  it "keeps text containing a bare < that is not a tag" do
    dirty = "1\n00:00:01,000 --> 00:00:02,000\n5 < 10, right? <3\n"
    expect(described_class.call(dirty)).to eq("1\n00:00:01,000 --> 00:00:02,000\n5 < 10, right? <3\n")
  end

  it "survives invalid UTF-8 bytes" do
    dirty = "1\n00:00:01,000 --> 00:00:02,000\nOl\xE1 mundo\n".dup.force_encoding(Encoding::UTF_8)
    expect { described_class.call(dirty) }.not_to raise_error
  end
end
