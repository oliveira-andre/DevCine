# Materializes admin catalog creations (feature: admin catalog wizard).
#
# Two entry points:
#   from_api!  — takes a CatalogLookup pick, creates the Movie or Serie with
#                seasons + per-episode PLACEHOLDER videos (private/uploading, no
#                file) and downloads the poster. Uploading later attaches the
#                file and flips the video public/ready.
#   vanilla!   — the manual wizard: just the record (+ empty seasons for a
#                serie); episodes are added at upload time.
class CatalogImport
  class << self
    def from_api!(kind:, source:, external_id:, uploader:)
      details = CatalogLookup.details(kind, source, external_id)
      return nil unless details

      item =
        if kind.to_s == "movie"
          create_movie!(details, uploader)
        else
          create_serie!(details, uploader) # serie and anime share the Serie model
        end
      attach_remote_image(item.poster, details[:poster_url])
      attach_remote_image(item.backdrop, details[:backdrop_url])
      item
    end

    def vanilla!(kind:, title:, description: nil, seasons_count: 1, uploader:)
      if kind.to_s == "movie"
        ActiveRecord::Base.transaction do
          Movie.create!(
            video: placeholder_video(title: title, kind: :feature, uploader: uploader),
            title: title, description: description
          )
        end
      else
        ActiveRecord::Base.transaction do
          serie = Serie.create!(title: title, description: description, status: :ongoing)
          [ seasons_count.to_i, 1 ].max.clamp(1, 50).times do |i|
            serie.seasons.create!(name: "Season #{i + 1}", position: i + 1)
          end
          serie
        end
      end
    end

    private

    def create_movie!(details, uploader)
      ActiveRecord::Base.transaction do
        Movie.create!(
          video: placeholder_video(title: details[:title], kind: :feature, uploader: uploader),
          title: details[:title],
          original_title: details[:title],
          description: details[:description],
          release_date: details[:release_date]
        )
      end
    end

    def create_serie!(details, uploader)
      ActiveRecord::Base.transaction do
        serie = Serie.create!(
          title: details[:title],
          description: details[:description],
          release_date: details[:release_date],
          status: details[:status].to_s == "ended" ? :ended : :ongoing
        )
        Array(details[:seasons]).each do |season_data|
          season = serie.seasons.create!(
            name: season_data[:name].presence || "Season #{season_data[:number]}",
            position: season_data[:number].to_i
          )
          Array(season_data[:episodes]).each do |ep|
            video = placeholder_video(
              title: "#{serie.title} S#{season.position}E#{ep[:number]}",
              kind: :episode, uploader: uploader
            )
            season.episodes.create!(
              video: video,
              title: ep[:title].presence || "Episode #{ep[:number]}",
              position: ep[:number].to_i
            )
          end
        end
        serie
      end
    end

    # No file yet: invisible to viewers (private) and marked uploading. The
    # upload step attaches the file and flips it public/ready.
    def placeholder_video(title:, kind:, uploader:)
      Video.create!(title: title, kind: kind, status: :uploading,
                    visibility: :private, uploader: uploader)
    end

    def attach_remote_image(attachment, url)
      return if url.blank?

      response = Faraday.get(url) { |req| req.options.timeout = 10 }
      return unless response.success? && response.body.present?

      filename = File.basename(URI.parse(url).path).presence || "poster.jpg"
      attachment.attach(
        io: StringIO.new(response.body), filename: filename,
        content_type: response.headers["content-type"].presence || "image/jpeg"
      )
    rescue Faraday::Error, URI::Error => e
      Rails.logger.warn("[CatalogImport] image download failed (#{url}): #{e.message}")
    end
  end
end
