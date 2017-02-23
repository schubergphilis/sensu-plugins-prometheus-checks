$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "sensu/plugins/prometheus/checks"

require 'simplecov'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.default_cassette_options = { record: :new_episodes }
end

SimpleCov.minimum_coverage 100
SimpleCov.start do
  coverage_dir 'spec/reports/coverage'
  add_filter '/spec/'
end
