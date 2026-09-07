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

  desc "Re-encode already-stored videos whose codec browsers can't decode " \
       "(HEVC / 10-bit → H.264 8-bit). Decodable files are left untouched; " \
       "audio tracks and subtitles are unaffected. CPU-heavy: minutes per " \
       "video — safe to interrupt and re-run (it picks up where it left off)."
  task reencode: :environment do
    unless VideoFrameExtractor.available?
      abort "ffmpeg/ffprobe is not runnable here — install or repair it before running this task."
    end

    scope = Video.where.not(kind: :live)
    total = scope.count
    processed = transcoded = safe = skipped = failed = 0

    puts "Checking #{total} videos…"

    scope.find_each do |video|
      processed += 1
      label = video.try(:slug).presence || video.id

      unless video.file.attached?
        skipped += 1
        next
      end

      started = Time.current
      result = VideoIngest.reencode(video)
      case result.status
      when :transcoded
        transcoded += 1
        puts "[#{processed}/#{total}] ✓ #{label} — re-encoded to H.264 in #{(Time.current - started).round}s"
      when :safe
        safe += 1
      else
        failed += 1
        warn "[#{processed}/#{total}] ✗ #{label} — #{result.error}"
      end
    end

    puts "Done. transcoded=#{transcoded} already_safe=#{safe} skipped=#{skipped} failed=#{failed} of #{total}."
  end

  desc "Build the segmented HLS package (hls.js playback + TV-safe audio " \
       "switching) for every ingested video that doesn't have one. Disk-bound " \
       "-c copy segmentation — safe to interrupt and re-run."
  task hls: :environment do
    unless VideoFrameExtractor.available?
      abort "ffmpeg/ffprobe is not runnable here — install or repair it before running this task."
    end

    scope = Video.where.not(kind: :live)
    total = scope.count
    processed = packaged = skipped = failed = 0

    puts "Packaging #{total} videos…"

    scope.find_each do |video|
      processed += 1
      label = video.try(:slug).presence || video.id

      if !video.file.attached? || video.hls_ready? || !video.audio_tracks.exists?
        skipped += 1
        next
      end

      result = HlsPackager.call(video)
      if result.ok?
        packaged += 1
        puts "[#{processed}/#{total}] ✓ #{label} — #{result.renditions} audio rendition(s)"
      else
        failed += 1
        warn "[#{processed}/#{total}] ✗ #{label} — #{result.error}"
      end
    end

    puts "Done. packaged=#{packaged} skipped=#{skipped} failed=#{failed} of #{total}."
  end
end
