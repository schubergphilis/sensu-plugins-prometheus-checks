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
      'ttl' => 300,
      'ttl_status' => 1,
      'source' => 'sbppapik8s-worker2',
      'status' => 0
    )
  end

  it '.run: only custom checks on success state' do
    config = YAML.load_file('spec/config/prometheus_checks_custom.yml')
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    runner.run
    expect(runner.status).to be 0
    expect(runner.output).to eq('OK: Ran 2 checks succesfully on 4 events!')

    expect(runner.events).to include(
      'address' => 'sbppapik8s-worker3.services.schubergphilis.com',
      'name' => 'heartbeat',
      'occurrences' => 3,
      'output' => 'OK: Endpoint is alive and kicking',
      'reported_by' => 'reported_by_host',
      'ttl' => 300,
      'ttl_status' => 1,
      'status' => 0
    )

    expect(runner.events).to include(
      'address' => 'datahub-rtwind-source-ebase-connector-ebase.services.schubergphilis.com',
      'name' => 'functional_check',
      'occurrences' => 3,
      'output' => 'OK: Functional Check is working!',
      'reported_by' => 'reported_by_host',
      'ttl' => 300,
      'ttl_status' => 1,
      'status' => 0
    )
  end

  it '.run: ignores invalid checks' do
    config = YAML.load_file('spec/config/prometheus_checks_custom_invalid.yml')
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    runner.run
    expect(runner.status).to be 1

    expect(runner.events).to include(
      'address' => 'sbppapik8s-worker3.services.schubergphilis.com',
      'name' => 'before',
      'occurrences' => 3,
      'output' => 'No output message defined for this check',
      'reported_by' => 'reported_by_host',
      'ttl' => 300,
      'ttl_status' => 1,
      'source' => 'sbppapik8s-worker3',
      'status' => 0
    )
    # This check is defined after the invalid check
    expect(runner.events).to include(
      'address' => 'sbppapik8s-worker3.services.schubergphilis.com',
      'name' => 'after',
      'occurrences' => 3,
      'output' => 'OK: Endpoint is alive and kicking',
      'reported_by' => 'reported_by_host',
      'ttl' => 300,
      'ttl_status' => 1,
      'source' => 'sbppapik8s-worker3',
      'status' => 0
    )
  end

  it '.run: expects events to be sent to the dispatcher' do
    config = YAML.load_file('spec/config/prometheus_checks.yml')
    config['config']['whitelist'] = '.*'
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    runner.run
    expect(runner.events.length).to_not eql(0)
  end

  it '.run: matches nothing because there is not anything whitelisted' do
    config = YAML.load_file('spec/config/prometheus_checks.yml')
    config['config']['whitelist'] = 'nothing_should_match_this'
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    runner.run
    expect(runner.events.length).to eql(0)
  end

  it '.run: matches only whitelisted hosts' do
    config = YAML.load_file('spec/config/prometheus_checks.yml')
    config['config']['whitelist'] = 'sbppapik8s-worker1'
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    runner.run
    expect(runner.events).to include(
      'address' => 'sbppapik8s-worker1.services.schubergphilis.com',
      'name' => 'heartbeat',
      'occurrences' => 3,
      'output' => 'OK: Endpoint is alive and kicking',
      'reported_by' => 'reported_by_host',
      'ttl' => 300,
      'ttl_status' => 1,
      'source' => 'sbppapik8s-worker1',
      'status' => 0
    )
    expect(runner.events).to_not include(
      'address' => 'sbppapik8s-worker3.services.schubergphilis.com',
      'name' => 'heartbeat',
      'occurrences' => 3,
      'output' => 'OK: Endpoint is alive and kicking',
      'reported_by' => 'reported_by_host',
      'ttl' => 300,
      'ttl_status' => 1,
      'source' => 'sbppapik8s-worker3',
      'status' => 0
    )
  end

  it '.run.sensu_safe: returns sensu safe check names' do
    config = YAML.load_file('spec/config/prometheus_checks.yml')
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    expect(runner.send(:sensu_safe, 'test')).to eql('test')
    expect(runner.send(:sensu_safe, 'test-hostname:9100')).to eql('test-hostname_9100')
    expect(runner.send(:sensu_safe, 'check_disk_/root/')).to eql('check_disk__root_')
  end

  it '.run.append_event: allows overriding the ttl' do
    config = YAML.load_file('spec/config/prometheus_checks.yml')
    config['config']['ttl'] = 180
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    expect(runner.send(:append_event, 'name', 'output', 'status', 'source')[0]['ttl']).to eql(180)
  end

  it '.run.append_event: allows overriding the ttl_status' do
    config = YAML.load_file('spec/config/prometheus_checks.yml')
    config['config']['ttl_status'] = 2
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    expect(runner.send(:append_event, 'name', 'output', 'status', 'source')[0]['ttl_status']).to eql(2)
  end

  it '.run: Allows overriding the status from the metric' do
    config = YAML.load_file('spec/config/prometheus_checks.yml')
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    runner.run

    expect(runner.events).to include(
      'address' => 'sbppapik8s.services.schubergphilis.com',
      'name' => 'check_predict_disk_all',
      'occurrences' => 3,
      'output' => 'Disks predicted to run out of space in the next 1 days: node-exporter1:9100:/var/lib/docker',
      'reported_by' => 'reported_by_host',
      'ttl' => 300,
      'ttl_status' => 1,
      'source' => 'sbppapik8s',
      'status' => 1
    )
  end

  it '.run.source_nodename_map: correctly maps the hostnames' do
    config = YAML.load_file('spec/config/prometheus_checks.yml')
    runner = Sensu::Plugins::Prometheus::Checks::Runner.new(config)
    source_nodename_map = runner.send(:source_nodename_map)
    expect(source_nodename_map).to include('node-exporter1:9100' => 'sbppapik8s-worker1',
                                           'node-exporter2:9100' => 'sbppapik8s-worker2',
                                           'node-exporter3:9100' => 'sbppapik8s-worker3')
  end
end
