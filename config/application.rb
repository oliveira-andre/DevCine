require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Devcine
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Serve Active Storage media through the proxy (stable, cacheable URLs served
    # by the app) rather than short-lived redirect URLs — feature 005, FR-015.
    # Proxy URLs are permanent (urls_expire_in defaults to nil = no expiry).
    config.active_storage.resolve_model_to_route = :rails_storage_proxy

    # The player streams video via redirect mode (see initializers/active_storage.rb),
    # whose disk-service URL otherwise expires after 5 minutes — mid-movie range
    # requests would start 404ing. Effectively eternal, matching the permanent
    # proxy URLs. NOTE: `nil` would NOT mean "never" here — the engine applies
    # `|| 5.minutes` to this setting, so it needs an explicit huge duration.
    config.active_storage.service_urls_expire_in = 100.years

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
