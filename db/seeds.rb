# Idempotent seeds for local development / demo.
#
# Media is loaded via Active Storage by attaching sample files from tmp/ (never
# copied into public/). The 435MB sample movie file is only attached when
# SEED_VIDEO_FILE=1 is set, to keep normal seeding fast.
#
#   bin/rails db:seed

require "open-uri"

MEDIA = {
  poster:   Rails.root.join("tmp/movies/movie_poster.webp"),
  backdrop: Rails.root.join("tmp/movies/movie_background.jpg"),
  serie:    Rails.root.join("tmp/series/beavis/serie_poster.jpg"),
  video:    Rails.root.join("tmp/movies/b_and_b_do_america.mp4")
}.freeze

CONTENT_TYPES = {
  ".webp" => "image/webp",
  ".jpg"  => "image/jpeg",
  ".jpeg" => "image/jpeg",
  ".mp4"  => "video/mp4"
}.freeze

def attach_file(attachment, path, filename: nil)
  return if attachment.attached?
  return unless File.exist?(path)

  filename ||= File.basename(path)
  attachment.attach(
    io: File.open(path),
    filename: filename,
    content_type: CONTENT_TYPES.fetch(File.extname(path).downcase, "application/octet-stream")
  )
end

# ---------------------------------------------------------------------------
# Test accounts (password: 12345678)
# ---------------------------------------------------------------------------
users = {
  member:  { email: "user@codeline.online",    role: :user,    name: "Test Viewer" },
  blocked: { email: "blocked@codeline.online", role: :blocked, name: "Blocked User" },
  admin:   { email: "admin@codeline.online",   role: :admin,   name: "Admin User" }
}.transform_values do |attrs|
  User.find_or_create_by!(email_address: attrs[:email]) do |u|
    u.password = "12345678"
    u.password_confirmation = "12345678"
    u.display_name = attrs[:name]
    u.role = attrs[:role]
  end
end

uploader = users[:admin]

# ---------------------------------------------------------------------------
# Catalog (only seeded once)
# ---------------------------------------------------------------------------
if Movie.count < 24
  24.times do |i|
    feature = Video.create!(
      title: "Feature Film #{i + 1}",
      description: "A seeded feature film.",
      duration_seconds: rand(4800..8400),
      kind: :feature,
      status: :ready,
      visibility: :public,
      file_size_bytes: 1_500_000_000,
      uploader: uploader,
      created_at: (i + 1).hours.ago
    )
    attach_file(feature.thumbnail, MEDIA[:poster], filename: "thumb.webp")

    movie = Movie.create!(
      video: feature,
      title: "Seeded Movie #{i + 1}",
      description: "A seeded Disney+-style movie.",
      release_date: Date.today - rand(1..3000),
      created_at: (i + 1).hours.ago
    )
    attach_file(movie.poster, MEDIA[:poster], filename: "poster.webp")
    attach_file(movie.backdrop, MEDIA[:backdrop], filename: "backdrop.jpg")
  end
end

# Standalone videos with a visibility mix (public / private / unlisted) so the
# public-only home filter is demonstrable. >50 to exercise the 50/pg limit.
if Video.standalone.count < 60
  60.times do |i|
    visibility = if (i % 5).zero? then :private
    elsif (i % 7).zero? then :unlisted
    else :public
    end
    video = Video.create!(
      title: "Standalone Clip #{i + 1}",
      description: "A seeded standalone video.",
      duration_seconds: rand(60..1800),
      kind: :standalone,
      status: :ready,
      visibility: visibility,
      file_size_bytes: 120_000_000,
      uploader: uploader,
      created_at: (i + 1).minutes.ago
    )
    attach_file(video.thumbnail, MEDIA[:poster], filename: "thumb.webp")
    attach_file(video.file, MEDIA[:video]) if ENV["SEED_VIDEO_FILE"] == "1" && i.zero?
  end
end

# Public live-kind videos back the "Lives" section and the live category.
if Video.live.count < 8
  8.times do |i|
    live = Video.create!(
      title: "Live Stream #{i + 1}",
      description: "A seeded live stream.",
      duration_seconds: rand(600..7200),
      kind: :live,
      status: :ready,
      visibility: :public,
      file_size_bytes: 0,
      uploader: uploader,
      created_at: (i + 1).minutes.ago
    )
    attach_file(live.thumbnail, MEDIA[:poster], filename: "thumb.webp")
  end
end

if Serie.count < 24
  24.times do |i|
    serie = Serie.create!(
      title: "Seeded Series #{i + 1}",
      description: "A seeded series.",
      release_date: Date.today - rand(1..3000),
      status: :ongoing,
      created_at: (i + 1).hours.ago
    )
    attach_file(serie.poster, MEDIA[:serie], filename: "serie_poster.jpg")
  end
end

# ---------------------------------------------------------------------------
# Genres + taggings (drive /search categories and genre browse)
# ---------------------------------------------------------------------------
genres = %w[Gaming Drama Action Suspense Terror].map do |name|
  Genre.find_or_create_by!(name: name)
end

if Tagging.none?
  Movie.all.each_with_index do |movie, i|
    Tagging.create!(genre: genres[i % genres.size], taggable: movie)
  end
  Serie.all.each_with_index do |serie, i|
    Tagging.create!(genre: genres[(i + 2) % genres.size], taggable: serie)
  end
end

# ---------------------------------------------------------------------------
# Watch history for the member (orders the "Last watched" rail)
# ---------------------------------------------------------------------------
member = users[:member]
if member.watch_progresses.none?
  Video.order(created_at: :desc).limit(4).each_with_index do |video, i|
    wp = WatchProgress.find_or_create_by!(user: member, video: video) do |progress|
      progress.position_seconds = rand(30..600)
      progress.completed = false
    end
    # Stagger last-watched ordering (most recent first).
    wp.update_column(:updated_at, (i + 1).minutes.ago)
  end
end

# ---------------------------------------------------------------------------
# Profile content for the member: uploads, likes, playlists, view history
# ---------------------------------------------------------------------------
if member.uploaded_videos.none?
  3.times do |i|
    v = Video.create!(
      title: "My Upload #{i + 1}", description: "A seeded member upload.",
      duration_seconds: rand(120..1800), kind: :standalone, status: :ready,
      visibility: (i.zero? ? :private : :public), maturity_rating: :L,
      file_size_bytes: 90_000_000, uploader: member, created_at: (i + 1).minutes.ago
    )
    attach_file(v.thumbnail, MEDIA[:poster], filename: "thumb.webp")
  end
end

# ---------------------------------------------------------------------------
# Restricted catalog (feature 006): PIN-gated title + an ungated public A18 one
# ---------------------------------------------------------------------------
if Video.visibility_restricted.none?
  restricted = Video.create!(
    title: "Restricted Feature", description: "A18 PIN-gated seeded title.",
    duration_seconds: 4800, kind: :standalone, status: :ready,
    visibility: :restricted, maturity_rating: :A18,
    file_size_bytes: 90_000_000, uploader: uploader
  )
  attach_file(restricted.thumbnail, MEDIA[:poster], filename: "thumb.webp")

  violent = Video.create!(
    title: "Public Violent Movie", description: "A18 but public — no PIN needed.",
    duration_seconds: 5400, kind: :standalone, status: :ready,
    visibility: :public, maturity_rating: :A18,
    file_size_bytes: 90_000_000, uploader: uploader
  )
  attach_file(violent.thumbnail, MEDIA[:poster], filename: "thumb.webp")
end

if member.likes.none?
  Video.visibility_public.limit(6).each { |v| Like.find_or_create_by!(user: member, likeable: v) }
end

if member.playlists.none?
  [ "Favorites", "Watch Later", "Best of 2026" ].each_with_index do |title, i|
    pl = Playlist.create!(user: member, title: title, visibility: (i == 2 ? :private : :public))
    Video.visibility_public.limit(rand(2..5)).each_with_index do |v, pos|
      PlaylistItem.create!(playlist: pl, video: v, position: pos + 1)
    end
  end
end

if member.video_views.none?
  Video.visibility_public.order(created_at: :desc).limit(6).each_with_index do |v, i|
    VideoView.create!(user: member, video: v, watched_at: (i + 1).hours.ago, ip_hash: SecureRandom.hex(8))
  end
end

puts "Seeded: #{User.count} users, #{Movie.count} movies, " \
     "#{Video.standalone.count} standalone videos, #{Serie.count} series, " \
     "#{member.uploaded_videos.count} member uploads, #{member.likes.count} likes, " \
     "#{member.playlists.count} playlists, #{member.video_views.count} views."
