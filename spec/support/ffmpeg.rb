# Examples tagged `:ffmpeg` shell out to the real binary. Skip them where
# ffmpeg is missing or broken (a Homebrew upgrade that leaves a dangling
# shared library will do it) rather than failing the suite over an environment
# problem — the surrounding behaviour is covered by stubbed examples.
RSpec.configure do |config|
  config.before(:each, :ffmpeg) do
    unless VideoFrameExtractor.available?
      skip "ffmpeg/ffprobe is not runnable here — install or repair it to run this example"
    end
  end
end
