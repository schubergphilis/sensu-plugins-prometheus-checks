require_relative '../bin/check_prometheus'

require 'rspec/expectations'

def slice(hash, *keys)
  Hash[ [keys, hash.values_at(*keys)].transpose]
end

RSpec::Matchers.define :include_hash_matching do |expected|
  match do |array_of_hashes|
    array_of_hashes.any? { |element| slice(element, *expected.keys) == expected }
  end
end

describe '#check' do
  it 'checks if value is ok' do
    expect(check(3,4,5)).to equal(0)
  end
  it 'checks if value is warning' do
    expect(check(4.1,4,5)).to equal(1)
  end
  it 'checks if value is critical' do
    expect(check(6,4,5)).to equal(2)
  end
end

describe '#equals' do
  it 'checks if value is equal' do
    expect(equals(1,1)).to equal(0)
  end
  it 'checks if value is not equal' do
    expect(equals(1,2)).to equal(2)
  end
end

describe '#query' do
  it 'can do a query' do
    expect(query('up')).to include('status' => 'success')
  end
end

describe '#safe_hostname' do
  it 'returns a safe hostname' do
    expect(safe_hostname('test-hostname:9100')).to eql('test_hostname_9100')
  end
end

describe '#memory' do
  it 'returns a list of memory values' do
    cfg = {'warn' => 90, 'crit' => 95}
    results = memory(cfg)
    expect(results).to include_hash_matching('output' => 'Memory 41%|memory=41', 'source' => 'node-exporter1:9100')
    expect(results).to include_hash_matching('output' => 'Memory 29%|memory=29', 'source' => 'node-exporter2:9100')
    expect(results).to include_hash_matching('output' => 'Memory 29%|memory=29', 'source' => 'node-exporter3:9100')
  end
end

describe '#disk' do
  it 'returns a list of disk values' do
    cfg = {'mount' => '/',
           'name' => 'root',
           'warn' => 90,
           'crit' => 95}
    results = disk(cfg)
    expect(results).to include_hash_matching('output' => 'Disk: 18%, Mountpoint: / |disk=18',
                                             'source' => 'node-exporter1:9100',
                                             'name'   => 'check_disk_root')
  end
end

describe '#inode' do
  it 'returns a list of inode values' do
    cfg = {'mount' => '/usr',
           'name' => 'usr',
           'warn' => 90,
           'crit' => 95}
    results = inode(cfg)
    expect(results).to include_hash_matching('output' => 'Disk: /usr, Inodes: 5% |inodes=5',
                                             'source' => 'node-exporter1:9100',
                                             'name'   => 'check_inodes_usr')
  end
end

describe '#service' do
  it 'checks a service is active' do
    cfg = {'name' => 'xenserver-pv-version.service'}
    results = service(cfg)
    expect(results).to include_hash_matching('output' => 'Service: xenserver-pv-version.service',
                                             'source' => 'node-exporter1:9100',
                                             'name'   => 'check_service_xenserver-pv-version.service')
  end
end

describe '#load_per_cluster' do
  it 'checks the load of the whole cluster' do
    cfg = {'cluster' => 'prometheus',
           'warn'    => '1.0',
           'crit'    => '2.0',
           'source'  => 'test'
          }
    results = load_per_cluster(cfg)
    expect(results).to include_hash_matching('output' => 'Cluster Load: 0.15|load=0.15',
                                             'source' => 'test',
                                             'name'   => 'cluster_load')
  end
end

describe '#load_per_cluster_minus_n' do
  it 'checks the load of the whole cluster' do
    cfg = {'cluster' => 'prometheus',
           'minus_n' => '1',
           'warn'    => '1.0',
           'crit'    => '2.0',
           'source'  => 'test'
          }
    results = load_per_cluster_minus_n(cfg)
    expect(results).to include_hash_matching('output' => 'Cluster Load: 0.22|load=0.22',
                                             'source' => 'test',
                                             'name'   => 'cluster_load_minus_n')
  end
end

describe '#custom' do
  it 'performs a custom prometheus query' do
    cfg = {'name' => 'heartbeat',
           'query' => 'up',
           'check' => {
             'type' => 'equals',
             'value' => 1
           },
           'msg'  => {
             0 => 'OK: Endpoint is alive and kicking',
             1 => 'CRIT: Endpoints not reachable!'
           }
          }
    results = custom(cfg)
    expect(results).to include_hash_matching('output' => 'OK: Endpoint is alive and kicking',
                                             'source' => 'node-exporter3:9100',
                                             'status' => 0,
                                             'name'   => 'heartbeat')
  end
end

describe '#precent_query_free' do
  it 'creates a prometheus query' do
    total = 'total_something{hello="world"}'
    available = 'available_something{world="hello"}'
    expect(percent_query_free(total,available)).to eq('100-((available_something{world="hello"}/total_something{hello="world"})*100)')
  end
  it 'accurately calculates the percentage free' do
    total = '100'
    available = '30'
    result = query(percent_query_free(total,available))
    expect(result['data']['result'][1]).to eq('70')
  end
end
