require 'spec_helper'

describe Sensu::Plugins::Prometheus::Checks::Output, :vcr do
  let(:prometheus) { Sensu::Plugins::Prometheus::Client.new }
  let(:metrics) { Sensu::Plugins::Prometheus::Metrics.new(prometheus) }
  let(:output) { Sensu::Plugins::Prometheus::Checks::Output.new }
  let(:whitelist) { '(^disk|inode|load|memory|_per_cluster)' }

  it 'instantiates a Output class' do
    expect(output).to be_a(Sensu::Plugins::Prometheus::Checks::Output)
  end

  it '.render' do
    vars = {
      'cfg' => {
        'name' => 'output_render_test',
        'state' => 'cfg_state'
      },
      'mount' => '/rspec/something',
      'name' => 'output_render_name',
      'state' => 2,
      'value' => 10
    }

    # selecting all the metric names based on whitelist
    metrics.public_methods.select { |m| m[/#{whitelist}/i] }.each do |metric_name|
      rendered = output.render(metric_name, vars)
      expect(rendered).to_not be_empty
      # trying to match empty fields on rendered output
      expect(rendered).to_not match(/(=,|=$|\(\)=|:$|:\s$)/)
    end
  end
end
