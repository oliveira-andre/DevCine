# Base class for external catalog API gateways (feature: admin catalog creation).
# Shares the HTTP plumbing (Faraday, timeouts, JSON parsing) and the small text
# parsers the gateways need. Gateways NEVER raise on network/API trouble — they
# log and return nil/[] so CatalogLookup can fall through to the next provider.
class ApplicationGateway
  TIMEOUT = 8
  OPEN_TIMEOUT = 4

  # Gateways that need an API key override this (checked before any request).
  def self.configured? = true

  # Whether the gateway can SEARCH by name (Fanart.tv can't — artwork only).
  def self.searchable? = true

  private

  def connection
    @connection ||= Faraday.new(url: self.class::BASE_URL) do |f|
      f.options.timeout = TIMEOUT
      f.options.open_timeout = OPEN_TIMEOUT
      f.headers["User-Agent"] = "DevCine/1.0"
    end
  end

  def get_json(path, params = {})
    response = connection.get(path, params)
    return nil unless response.success?

    JSON.parse(response.body, symbolize_names: true)
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.warn("[#{self.class.name}] GET #{path} failed: #{e.class}: #{e.message}")
    nil
  end

  def post_json(path, body)
    response = connection.post(path) do |req|
      req.headers["Content-Type"] = "application/json"
      req.headers["Accept"] = "application/json"
      req.body = body.to_json
    end
    return nil unless response.success?

    JSON.parse(response.body, symbolize_names: true)
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.warn("[#{self.class.name}] POST #{path} failed: #{e.class}: #{e.message}")
    nil
  end

  # --- shared parsers ---------------------------------------------------------

  # API descriptions often carry markup (AniList <br>, TVmaze <p>). Plain text only.
  def strip_html(text)
    return nil if text.blank?

    text.to_s.gsub(/<br\s*\/?>/i, "\n").gsub(/<[^>]+>/, "").strip.presence
  end

  # "2013-04-07" → Date, tolerating junk/absence.
  def safe_date(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue Date::Error
    nil
  end
end
