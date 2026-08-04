namespace :thumbnails do
  desc "Attach a thumbnail (first extracted frame) to every non-live video that has a file but no thumbnail"
  task backfill: :environment do
    unless VideoFrameExtractor.available?
      abort "ffmpeg/ffprobe is not runnable here — install or repair it before running this task."
    end

    # Lives play via an embed URL and have no file to extract from.
    scope = Video.where.not(kind: :live)
    total = scope.count
    processed = attached = skipped = failed = 0

    puts "Backfilling thumbnails across #{total} videos…"

    scope.find_each do |video|
      processed += 1
      label = video.try(:slug).presence || video.id

      if video.thumbnail.attached?
        skipped += 1
        next
      end
      unless video.file.attached?
        skipped += 1
        next
      end

      begin
        if video.attach_generated_thumbnail!
          attached += 1
          puts "[#{processed}/#{total}] ✓ #{label}"
        else
          failed += 1
          warn "[#{processed}/#{total}] ✗ #{label} — no frame could be extracted"
        end
      rescue StandardError => e
        failed += 1
        warn "[#{processed}/#{total}] ✗ #{label} — #{e.class}: #{e.message}"
      end
    end

    puts "Done. attached=#{attached} skipped=#{skipped} (already had one or no file) failed=#{failed} of #{total}."
  end
end
