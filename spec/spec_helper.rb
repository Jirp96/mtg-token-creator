require "webmock/rspec"

PROJECT_ROOT = File.expand_path("..", __dir__)
FIXTURES_DIR = File.join(PROJECT_ROOT, "spec", "fixtures")

$LOAD_PATH.unshift File.join(PROJECT_ROOT, "lib")

# WebMock disables real network connections by default; individual specs stub
# the Scryfall endpoints they exercise.

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

def fixture(*parts)
  File.join(FIXTURES_DIR, *parts)
end

def load_json_fixture(name)
  require "json"
  JSON.parse(File.read(fixture(name)))
end
