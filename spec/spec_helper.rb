lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'yaml'
require 'rspec/expectations'
require 'vcr'
require 'simplecov'
require 'codecov'

if ENV['TRAVIS'] == 'true'
  SimpleCov.formatters = [
    SimpleCov::Formatter::Codecov,
    SimpleCov::Formatter::HTMLFormatter
  ]
else
  SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
end

require 'sensu/plugins/events/dispatcher'
require 'sensu/plugins/prometheus/client'
require 'sensu/plugins/prometheus/metrics'
require 'sensu/plugins/prometheus/checks'
require 'sensu/plugins/prometheus/checks/output'
require 'sensu/plugins/prometheus/checks/version'
require 'sensu/plugins/prometheus/checks/runner'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.default_cassette_options = { record: :new_episodes }
end

# setting up environment variables that trigger VCR calls
ENV['PROM_DEBUG'] = 'true'
ENV['PROMETHEUS_ENDPOINT'] = '127.0.0.1:19090'
ENV['SENSU_SOCKET_ADDRESS'] = '127.0.0.1'
ENV['SENSU_SOCKET_PORT'] = '3030'
