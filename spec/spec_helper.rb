lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'yaml'
require 'rspec/expectations'
require 'vcr'
require 'simplecov'

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
