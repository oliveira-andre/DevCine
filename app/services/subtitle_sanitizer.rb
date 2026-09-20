require "cgi"

# Cleans an SRT's text down to plain words (MKV ingest). ffmpeg's ASS → SRT
# conversion translates the ASS styling into HTML (<font …>, <b>, <i>) and
# leaves positioning overrides as literal "{\an8}" text — browsers render all
# of that as visible junk. Only cue TEXT lines are touched: index and timing
# lines pass through untouched, so the time tracking is exactly what ffmpeg
# extracted. Cues with no text left (pure styling/karaoke effects) are
# dropped whole, and the survivors renumbered.
class SubtitleSanitizer
  TIMING_LINE = /\A\d{2}:\d{2}:\d{2}[,.]\d{3}\s+--?>\s+\d{2}:\d{2}:\d{2}[,.]\d{3}/
  HTML_TAG = %r{</?[a-zA-Z][^>]*>}
  ASS_OVERRIDE = /\{\\[^}]*\}/

  def self.call(srt)
    new(srt).call
  end

  def initialize(srt)
    @srt = srt.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
  end

  def call
    cues = @srt.delete_prefix("\u{FEFF}").gsub("\r\n", "\n").split(/\n{2,}/)

    cleaned = cues.filter_map do |cue|
      lines = cue.split("\n")
      timing_at = lines.index { |l| l.match?(TIMING_LINE) }
      next if timing_at.nil?

      text = lines[(timing_at + 1)..].filter_map do |line|
        stripped = clean_line(line)
        stripped unless stripped.empty?
      end
      next if text.empty?

      [ lines[timing_at], *text ]
    end

    cleaned.each_with_index
           .map { |(timing, *text), i| [ i + 1, timing, *text ].join("\n") }
           .join("\n\n") << "\n"
  end

  private

  def clean_line(line)
    CGI.unescapeHTML(line.gsub(HTML_TAG, "").gsub(ASS_OVERRIDE, ""))
       .gsub(/[[:space:]]+/, " ")
       .strip
  end
end
