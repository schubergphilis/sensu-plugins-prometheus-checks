require 'spec_helper'
require_relative '../bin/check_prometheus'

require 'rspec/expectations'

ENV['PROMETHEUS_ENDPOINT'] = 'localhost:19090'

def slice(hash, *keys)
  Hash[[keys, hash.values_at(*keys)].transpose]
end

RSpec::Matchers.define :include_hash_matching do |expected|
  match do |array_of_hashes|
    array_of_hashes.any? { |element| slice(element, *expected.keys) == expected }
  end
end

describe '#check' do
  it 'checks if value is ok' do
    expect(check(3, 4, 5)).to equal(0)
  end
  it 'checks if value is warning' do
    expect(check(4.1, 4, 5)).to equal(1)
  end
  it 'checks if value is critical' do
    expect(check(6, 4, 5)).to equal(2)
  end
end

describe '#equals' do
  it 'checks if value is equal' do
    expect(equals(1, 1)).to equal(0)
  end
  it 'checks if value is not equal' do
    expect(equals(1, 2)).to equal(2)
  end
end

describe '#query_prometheus', :vcr do
  it 'can do a query' do
    expect(query_prometheus('up')).to include('status' => 'success')
  end
end

describe '#sensu_safe' do
  it 'returns a safe hostname' do
    expect(sensu_safe('test-hostname:9100')).to eql('test-hostname_9100')
  end
  it 'returns a safe check name' do
    expect(sensu_safe('check_disk_/root/')).to eql('check_disk__root_')
  end
end

describe '#memory', :vcr do
  it 'returns a list of memory values' do
    cfg = { 'warn' => 90, 'crit' => 95 }
    results = memory(cfg)
    expect(results).to include_hash_matching('output' => 'Memory 41%|memory=41', 'source' => 'node-exporter1:9100')
    expect(results).to include_hash_matching('output' => 'Memory 29%|memory=29', 'source' => 'node-exporter2:9100')
    expect(results).to include_hash_matching('output' => 'Memory 29%|memory=29', 'source' => 'node-exporter3:9100')
  end
end

describe '#disk', :vcr do
  it 'returns a list of disk values' do
    cfg = { 'mount' => '/',
            'name' => 'root',
            'warn' => 90,
            'crit' => 95 }
    results = disk(cfg)
    expect(results).to include_hash_matching('output' => 'Disk: 18%, Mountpoint: / |disk=18',
                                             'source' => 'node-exporter1:9100',
                                             'name'   => 'check_disk_root')
  end
end

describe '#disk_all', :vcr do
  it 'returns a list of disk values' do
    cfg = { 'ignore_fs' => 'tmpfs',
            'warn' => 90,
            'crit' => 95 }
    results = disk_all(cfg)
    expect(results).to include_hash_matching('output' => 'Disk: /, Usage: 18% |disk=18',
                                             'source' => 'node-exporter1:9100',
                                             'name'   => 'check_disk_root')
    expect(results).to include_hash_matching('output' => 'Disk: /var/lib/docker, Usage: 29% |disk=29',
                                             'source' => 'node-exporter2:9100',
                                             'name'   => 'check_disk_var_lib_docker')
    expect(results).to include_hash_matching('output' => 'Disk: /var/lib/docker, Inode Usage: 8% |inodes=8',
                                             'source' => 'node-exporter2:9100',
                                             'name'   => 'check_inode_var_lib_docker')
    expect(results).not_to include_hash_matching('name' => 'check_disk_run')
  end
  it 'allows overriding the ignore_fs' do
    cfg = { 'ignore_fs' => 'test',
            'warn' => 90,
            'crit' => 95 }
    results = disk_all(cfg)
    expect(results).to include_hash_matching('name' => 'check_disk_run')
  end
end

describe '#inode', :vcr do
  it 'returns a list of inode values' do
    cfg = { 'mount' => '/usr',
            'name' => 'usr',
            'warn' => 90,
            'crit' => 95 }
    results = inode(cfg)
    expect(results).to include_hash_matching('output' => 'Disk: /usr, Inodes: 5% |inodes=5',
                                             'source' => 'node-exporter1:9100',
                                             'name'   => 'check_inodes_usr')
  end
end

describe '#predict_disk_all', :vcr do
  it 'predicts no disks getting full ' do
    cfg = { 'days' => '30',
            'source' => 'test123' }
    results = predict_disk_all(cfg)
    expect(results).to eql('output' => 'No disks are predicted to run out of space in the next 2592000 days',
                           'name' => 'predict_disks',
                           'source' => 'test123',
                           'status' => 0)
  end
  it 'predicts a disk getting full' do
    cfg = { 'days' => '30',
            'source' => 'test123' }
    results = predict_disk_all(cfg)
    expect(results).to eql('output' => 'Disks predicted to run out of space in the next 2592000 days: node-exporter1:9100:/,node-exporter1:9100:/var/lib/docker',
                           'name' => 'predict_disks',
                           'source' => 'test123',
                           'status' => 1)
  end
end

describe '#service', :vcr do
  it 'checks a service not running' do
    cfg = { 'name' => 'not-running.service' }
    results = service(cfg)
    expect(results).to include_hash_matching('output' => 'Service: not-running.service (active=0)',
                                             'status' => 2,
                                             'source' => 'node-exporter1:9100',
                                             'name'   => 'check_service_not-running.service')
  end
  it 'checks a service running' do
    cfg = { 'name' => 'running.service' }
    results = service(cfg)
    expect(results).to include_hash_matching('output' => 'Service: running.service (active=1)',
                                             'status' => 0,
                                             'source' => 'node-exporter1:9100',
                                             'name'   => 'check_service_running.service')
  end
  it 'checks a service failure' do
    cfg = { 'name' => 'failed.service', 'state' => 'failed', 'state_required' => 0 }
    results = service(cfg)
    expect(results).to include_hash_matching('output' => 'Service: failed.service (failed=1)',
                                             'status' => 2,
                                             'source' => 'node-exporter1:9100',
                                             'name'   => 'check_service_failed.service')
  end
end

describe '#load_per_cluster', :vcr do
  it 'checks the load of the whole cluster' do
    cfg = { 'cluster' => 'prometheus',
            'warn'    => '1.0',
            'crit'    => '2.0',
            'source'  => 'test' }
    results = load_per_cluster(cfg)
    expect(results).to include_hash_matching('output' => 'Cluster Load: 0.15|load=0.15',
                                             'source' => 'test',
                                             'name'   => 'cluster_prometheus_load')
  end
end

describe '#load_per_cluster_minus_n', :vcr do
  it 'checks the load of the whole cluster' do
    cfg = { 'cluster' => 'prometheus',
            'minus_n' => '1',
            'warn'    => '1.0',
            'crit'    => '2.0',
            'source'  => 'test' }
    results = load_per_cluster_minus_n(cfg)
    expect(results).to include_hash_matching('output' => 'Cluster Load: 0.22|load=0.22',
                                             'source' => 'test',
                                             'name'   => 'cluster_prometheus_load_minus_n')
  end
end

describe '#custom', :vcr do
  it 'performs a custom prometheus query' do
    cfg = { 'name' => 'heartbeat',
            'query' => 'up',
            'check' => {
              'type' => 'equals',
              'value' => 1
            },
            'msg' => {
              0 => 'OK: Endpoint is alive and kicking',
              1 => 'CRIT: Endpoints not reachable!'
            } }
    results = custom(cfg)
    expect(results).to include_hash_matching('output' => 'OK: Endpoint is alive and kicking',
                                             'source' => 'node-exporter3:9100',
                                             'status' => 0,
                                             'name'   => 'heartbeat')
  end
end

describe '#precent_query_free', :vcr do
  it 'creates a prometheus query' do
    total = 'total_something{hello="world"}'
    available = 'available_something{world="hello"}'
    expect(percent_query_free(total, available)).to eq('100-((available_something{world="hello"}/total_something{hello="world"})*100)')
  end
  it 'accurately calculates the percentage free' do
    total = '100'
    available = '30'
    result = query_prometheus(percent_query_free(total, available))
    expect(result['data']['result'][1]).to eq('70')
  end
end

describe '#nice_disk_name' do
  it 'returns a nice disk name for root' do
    expect(nice_disk_name('/')).to eql('root')
  end
  it 'returns a nice disk name for a disk with lots of slashes' do
    expect(nice_disk_name('/lots/of/slashes/')).to eql('lots_of_slashes')
  end
end

describe '#load_per_cpu', :vcr do
  it 'returns a list of load values' do
    cfg = { 'warn' => 2.0, 'crit' => 4.0 }
    results = load_per_cpu(cfg)
    expect(results).to include_hash_matching('output' => 'Load: 0.15|load=0.15', 'source' => 'node-exporter1:9100')
  end
end

describe '#memory_per_cluster', :vcr do
  it 'checks the memory of the whole cluster' do
    cfg = { 'cluster' => 'prometheus',
            'warn'    => '80',
            'crit'    => '90',
            'source'  => 'test' }
    results = memory_per_cluster(cfg)
    expect(results).to include_hash_matching('output' => 'Cluster Memory: 33%|memory=33',
                                             'source' => 'test',
                                             'name'   => 'cluster_prometheus_memory')
  end
end

describe '#map_nodenames', :vcr do
  it 'creates a map of instance to nodenames' do
    results = map_nodenames
    expect(results).to include('node-exporter1:9100' => 'sbppapik8s-worker1',
                               'node-exporter2:9100' => 'sbppapik8s-worker2',
                               'node-exporter3:9100' => 'sbppapik8s-worker3')
  end
end

describe '#build_event', :vcr do
  it 'builds an event with replaced values' do
    cfg = { 'reported_by' => 'reported_by_host',
            'occurences' => 5,
            'domain' => 'example.com' }
    node_map = { 'instance_name' => 'node_name' }
    event = { 'source' => 'instance_name',
              'name'          => 'check_name',
              'extra_field'   => 'value' }
    results = build_event(event, node_map, cfg)
    expect(results).to include('address' => 'node_name.example.com',
                               'source' => 'node_name',
                               'name' => 'check_name',
                               'extra_field' => 'value',
                               'occurrences' => 5,
                               'reported_by' => 'reported_by_host')
  end
  it 'uses default values when they cant be found' do
    cfg = { 'reported_by' => 'reported_by_host',
            'domain' => 'example.com' }
    node_map = { 'not_instance_name' => 'node_name' }
    event = { 'source' => 'instance_name',
              'name'          => 'check_name',
              'extra_field'   => 'value' }
    results = build_event(event, node_map, cfg)
    expect(results).to include('address' => 'instance_name.example.com',
                               'source' => 'instance_name',
                               'name' => 'check_name',
                               'extra_field' => 'value',
                               'occurrences' => 1,
                               'reported_by' => 'reported_by_host')
  end
end

describe '#run', :vcr do
  $event_list = []
  def send_event(event)
    $event_list << event
  end

  before(:each) do
    $event_list = []
  end

  it 'fails to run a check' do
    checks = YAML.load_file('config.yml')
    checks['checks'][0] = ['this_will_fail']
    checks['custom'][0] = ['this_will_fail']
    expect { run(checks) }.to output(/Check:.*failed!/).to_stdout
  end

  it 'has a valid config with checks that can run' do
    checks = YAML.load_file('config.yml')
    expect { run(checks) }.to_not output(/Check:.*failed!/).to_stdout
  end

  it 'debugs output if PROM_DEBUG is set' do
    ENV['PROM_DEBUG'] = 'true'
    checks = YAML.load_file('config.yml')
    expect { run(checks) }.to output(/.*Service:.*/).to_stdout
    ENV['PROM_DEBUG'] = nil
  end

  it 'does a full e2e test using the config file' do
    checks = YAML.load_file('config.yml')
    status, output = run(checks)
    expect(status).to eql 1
    expect(output).to include('Source: sbppapik8s-worker2: Check: check_service_not-running.service: Output: Service: not-running.service (active=0): Status: 2')
    expect($event_list).to include_hash_matching('status' => 0,
                                                 'output' => 'OK: Endpoint is alive and kicking',
                                                 'source' => 'sbppapik8s-worker1',
                                                 'name' => 'heartbeat',
                                                 'reported_by' => 'reported_by_host',
                                                 'occurrences' => 3,
                                                 'address' => 'sbppapik8s-worker1.services.schubergphilis.com')
  end
  it 'returns a warning if a check fails' do
    checks = YAML.load_file('config.yml')
    status, output = run(checks)
    expect(status).to eql 1
    expect(output).to include('Source: sbppapik8s-worker2: Check: check_service_not-running.service: Output: Service: not-running.service (active=0): Status: 2')
  end
  it 'returns succussfully if all checks pass' do
    checks = {
      'config' => {
        'reported_by' => 'reported_by_host', 'domain' => 'services.schubergphilis.com', 'occurences' => 3, 'whitelist' => 'sbppapik8s-worker1'
      },
      'checks' => [{
        'check' => 'service', 'cfg' => {
          'name' => 'running.service'
        }
      }],
      'custom' => [{
        'name' => 'heartbeat', 'query' => 'up',
        'check' => {
          'type' => 'equals', 'value' => 1
        },
        'msg' => {
          0 => 'OK: Endpoint is alive and kicking', 2 => 'CRIT: Endpoints not reachable!'
        }
      }]
    }
    status, output = run(checks)
    expect(status).to eql 0
    expect(output).to include('OK: ')
    expect($event_list).to include_hash_matching('status' => 0,
                                                 'output' => 'Service: running.service (active=1)',
                                                 'source' => 'sbppapik8s-worker1',
                                                 'name' => 'check_service_running.service',
                                                 'reported_by' => 'reported_by_host',
                                                 'occurrences' => 3,
                                                 'address' => 'sbppapik8s-worker1.services.schubergphilis.com')
  end
  it 'drops a check if it does not match the whitelist' do
    checks = {
      'config' => {
        'reported_by' => 'reported_by_host', 'domain' => 'services.schubergphilis.com', 'occurences' => 3, 'whitelist' => 'notmatchinganything'
      },
      'checks' => [{
        'check' => 'service', 'cfg' => {
          'name' => 'running.service'
        }
      }],
      'custom' => [{
        'name' => 'heartbeat', 'query' => 'up',
        'check' => {
          'type' => 'equals', 'value' => 1
        },
        'msg' => {
          0 => 'OK: Endpoint is alive and kicking', 2 => 'CRIT: Endpoints not reachable!'
        }
      }]
    }
    status, output = run(checks)
    expect(status).to eql(0)
    expect(output).to include('OK: ')
    expect($event_list).not_to include_hash_matching('status' => 0,
                                                     'output' => 'Service: running.service (active=1)',
                                                     'source' => 'sbppapik8s-worker1',
                                                     'name' => 'check_service_running.service',
                                                     'reported_by' => 'reported_by_host',
                                                     'occurrences' => 3,
                                                     'address' => 'sbppapik8s-worker1.services.schubergphilis.com')
  end
  it 'debugs the output of checks not matching the whitelist' do
    ENV['PROM_DEBUG'] = 'true'
    checks = {
      'config' => {
        'reported_by' => 'reported_by_host', 'domain' => 'services.schubergphilis.com', 'occurences' => 3, 'whitelist' => 'notmatchinganything'
      },
      'checks' => [{
        'check' => 'service', 'cfg' => {
          'name' => 'running.service'
        }
      }],
      'custom' => [{
        'name' => 'heartbeat', 'query' => 'up',
        'check' => {
          'type' => 'equals', 'value' => 1
        },
        'msg' => {
          0 => 'OK: Endpoint is alive and kicking', 2 => 'CRIT: Endpoints not reachable!'
        }
      }]
    }
    expect { run(checks) }.to output(/Event dropped because source.*/).to_stdout
  end
  ENV['PROM_DEBUG'] = nil
end
