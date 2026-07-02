require "capybara/rspec"
require "selenium-webdriver"

# Mobile-first: system specs default to a mobile viewport (Constitution III).
# Tag an example with `desktop: true` to drive it at desktop size.
MOBILE_VIEWPORT  = [ 390, 844 ].freeze
DESKTOP_VIEWPORT = [ 1440, 900 ].freeze

def build_headless_chrome(app, width:, height:)
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=#{width},#{height}")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.register_driver(:headless_chrome_mobile) do |app|
  build_headless_chrome(app, width: MOBILE_VIEWPORT[0], height: MOBILE_VIEWPORT[1])
end

Capybara.register_driver(:headless_chrome_desktop) do |app|
  build_headless_chrome(app, width: DESKTOP_VIEWPORT[0], height: DESKTOP_VIEWPORT[1])
end

Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :headless_chrome_mobile
  end

  config.before(:each, type: :system, desktop: true) do
    driven_by :headless_chrome_desktop
  end
end
