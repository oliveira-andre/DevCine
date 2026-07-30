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
  member:  { email: "user@codeline.company",    role: :user,    name: "Test Viewer" },
  blocked: { email: "blocked@codeline.company", role: :blocked, name: "Blocked User" },
  admin:   { email: "admin@codeline.company",   role: :admin,   name: "Admin User" }
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
      title: "Standalone Clip #{i + 1} #{"actual playable video" if i == 1}",
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
    attach_file(video.file, MEDIA[:video]) if i == 1
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
      live_embed_url: "https://www.youtube.com/embed/O8bnDdWsk8Q",
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
# One rich series with seasons + episodes (feature 007 collection-show demo):
# season 1 has 15 episodes (> one page → infinite scroll), season 2 has 4.
# ---------------------------------------------------------------------------
if Episode.none?
  serie = Serie.order(:created_at).first
  [ [ 1, 15 ], [ 2, 4 ] ].each do |num, count|
    season = Season.create!(serie: serie, name: "Season #{num}", position: num)
    count.times do |i|
      ep_video = Video.create!(
        title: "#{serie.title} S#{num}E#{i + 1}",
        description: "Episode #{i + 1} of season #{num}.",
        duration_seconds: rand(1200..2600), kind: :episode, status: :ready,
        visibility: :public, maturity_rating: :A12, uploader: uploader
      )
      attach_file(ep_video.thumbnail, MEDIA[:poster], filename: "thumb.webp")
      Episode.create!(season: season, video: ep_video, title: "Episode #{i + 1}", position: i + 1)
    end
  end
end

# ---------------------------------------------------------------------------
# Genres + taggings (drive /search categories and genre browse). This list is
# authoritative — any genre not in it is pruned (with its taggings) on seed.
# ---------------------------------------------------------------------------
genre_names = [
  "Featured", "Animation", "Action/Adventure", "IMAX Enhanced", "Science Fiction",
  "Fantasy", "Horror", "Thrillers", "Kids", "Comedy", "Romantic Comedies",
  "Documentary", "Crime", "Drama", "Music", "Shorts", "Sports"
]
genres = genre_names.map { |name| Genre.find_or_create_by!(name: name) }
Genre.where.not(name: genre_names).destroy_all

# ---------------------------------------------------------------------------
# Orderings (feature 011): configurable sort options. "most recent" is the
# built-in system default (not a record); none of these is marked default, so
# listings still open "most recent".
# ---------------------------------------------------------------------------
[
  { label: "Most older", field: "created_at", direction: "asc",  position: 1 },
  { label: "A-Z",        field: "title",      direction: "asc",  position: 2 },
  { label: "Z-A",        field: "title",      direction: "desc", position: 3 }
].each do |attrs|
  Ordering.find_or_create_by!(label: attrs[:label]) do |o|
    o.field = attrs[:field]
    o.direction = attrs[:direction]
    o.position = attrs[:position]
  end
end

# ---------------------------------------------------------------------------
# Subtitles (feature 012): attach two SRT tracks (English default + Spanish) to
# the one playable standalone clip so the caption toggle + language menu work.
# ---------------------------------------------------------------------------
playable = Video.joins(:file_attachment).where.not(kind: :live).first
if playable && playable.subtitles.none?
  english_srt = Rails.root.join("tmp/movies/Beavis and Butthead - Do America-eng.srt")

  english = playable.subtitles.new(language: :english, is_default: true)
  if File.exist?(english_srt)
    english.file.attach(io: File.open(english_srt), filename: "english.srt", content_type: "application/x-subrip")
  else
    english.file.attach(io: StringIO.new("1\n00:00:01,000 --> 00:00:04,000\nWelcome to DevCine.\n"),
                        filename: "english.srt", content_type: "application/x-subrip")
  end
  english.save!

  # A second (Spanish, UTF-8) track exercises the language menu + non-ASCII path.
  spanish = playable.subtitles.new(language: :spanish)
  spanish.file.attach(
    io: StringIO.new("1\n00:00:01,000 --> 00:00:04,000\nBienvenido a DevCine.\n\n" \
                     "2\n00:00:05,000 --> 00:00:09,000\nDisfruta la función.\n"),
    filename: "spanish.srt", content_type: "application/x-subrip"
  )
  spanish.save!
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

# A playlist with more than one page of videos (feature 007 infinite-scroll demo).
if member.playlists.where(title: "Big Mix").none?
  big = Playlist.create!(user: member, title: "Big Mix", visibility: :public)
  Video.visibility_public.limit(15).each_with_index do |v, pos|
    PlaylistItem.create!(playlist: big, video: v, position: pos + 1)
  end
end

# Mark one episode of the rich series as watched so the collection show page
# demonstrates the "current episode" marker + Continue out of the box (feature
# 007). Normally the player records this on playback start; seeded episodes have
# no file to play, so we record it here.
episode_video = Video.where(kind: :episode).order(:created_at).offset(2).first
if episode_video && member.video_views.where(video: episode_video).none?
  VideoView.record!(member, episode_video)
  WatchProgress.record!(member, episode_video, position: 90, duration: episode_video.duration_seconds)
end

puts "Seeded: #{User.count} users, #{Movie.count} movies, " \
     "#{Video.standalone.count} standalone videos, #{Serie.count} series, " \
     "#{member.uploaded_videos.count} member uploads, #{member.likes.count} likes, " \
     "#{member.playlists.count} playlists, #{member.video_views.count} views."
