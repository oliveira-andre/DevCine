require "database_cleaner/active_record"

# Per-test isolation is handled by transactional fixtures (see rails_helper),
# which also share the connection with the Selenium system-test server thread.
# DatabaseCleaner truncates once before the suite to clear any rows left
# committed by a previous run (e.g. seeds or an aborted run).
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end
end
