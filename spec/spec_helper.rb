require 'simplecov'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.default_cassette_options = { :record => :new_episodes }
end

SimpleCov.minimum_coverage 100
SimpleCov.start do
  add_filter "/spec/"
end
