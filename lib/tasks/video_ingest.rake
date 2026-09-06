namespace :videos do
  desc "Backfill MKV ingest for already-uploaded videos: remux MKVs to MP4, " \
       "strip their audio tracks into named AudioTracks and embedded text " \
       "subtitles into Subtitle records; give every other video its 'default' " \
       "audio track row. Videos that already have audio tracks are skipped."
  task ingest: :environment do
    unless VideoFrameExtractor.available?
      abort "ffmpeg/ffprobe is not runnable here — install or repair it before running this task."
    end

    scope = Video.where.not(kind: :live)
    total = scope.count
    processed = remuxed = defaulted = skipped = failed = 0

    puts "Ingesting #{total} videos…"

    scope.find_each do |video|
      processed += 1
      label = video.try(:slug).presence || video.id

      unless video.file.attached?
        skipped += 1
        next
      end
      if video.audio_tracks.exists?
        skipped += 1
        next
      end

      result = VideoIngest.call(video)
      case result.status
      when :remuxed
        remuxed += 1
        puts "[#{processed}/#{total}] ✓ #{label} — MKV: #{result.audio_tracks} audio track(s), #{result.subtitles} subtitle(s)"
      when :default
        defaulted += 1
        puts "[#{processed}/#{total}] ✓ #{label} — default track"
      when :skipped
        skipped += 1
      else
        failed += 1
        warn "[#{processed}/#{total}] ✗ #{label} — #{result.error}"
      end
    end

    puts "Done. remuxed=#{remuxed} defaulted=#{defaulted} skipped=#{skipped} failed=#{failed} of #{total}."
  end
end
