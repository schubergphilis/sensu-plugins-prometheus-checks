require 'spec_helper'

describe Sensu::Plugins::Prometheus::Checks::Runner, :vcr do
  it 'instantiates a Run class' do
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(
      'config' => {}, 'checks' => {}, 'custom' => {}
    )
    expect(runner).to be_a(Sensu::Plugins::Prometheus::Checks::Runner)
  end

  it '.run: Returns a warning state and long output message' do
    config = YAML.load_file('spec/config/prometheus_checks.yml')
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    runner.run

    expect(runner.status).to be 1

    # final output message should concatenate more checks
    expect(runner.output).to include(' | ')

    expect(runner.output).to include(
      'Source: sbppapik8s-worker3, ' \
      'Check: check_service_xenserver-pv-version.service, ' \
      'Output: Service: xenserver-pv-version.service (active=0), Status: 2'
    )

    expect(runner.events).to include(
      'address' => 'sbppapik8s-worker2.services.schubergphilis.com',
      'name' => 'check_memory',
      'occurrences' => 3,
      'output' => 'Memory 29% |memory=29',
      'reported_by' => 'reported_by_host',
      'status' => 0,
      'source' => 'sbppapik8s-worker2'
    )
  end

  it '.run: only custom checks on success state' do
    config = YAML.load_file('spec/config/prometheus_checks_custom.yml')
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    runner.run
    expect(runner.status).to be 0
    expect(runner.output).to eq('OK: Ran 1 checks succesfully on 3 events!')
    expect(runner.events).to include(
      'address' => 'sbppapik8s-worker3.services.schubergphilis.com',
      'name' => 'custom_heartbeat',
      'occurrences' => 3,
      'output' => 'OK: Endpoint is alive and kicking',
      'reported_by' => 'reported_by_host',
      'status' => 0,
      'source' => 'sbppapik8s-worker3'
    )
  end
end
