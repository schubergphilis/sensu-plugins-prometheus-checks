require 'spec_helper'

describe Sensu::Plugins::Prometheus::Metrics, :vcr do
  let(:prometheus) { Sensu::Plugins::Prometheus::Client.new }
  let(:metrics) { Sensu::Plugins::Prometheus::Metrics.new(prometheus) }

  it 'instantiates a Metrics class' do
    expect(metrics).to be_a(Sensu::Plugins::Prometheus::Metrics)
  end

  it '.custom' do
    cfg = {
      'name' => 'heartbeat',
      'query' => 'up',
      'check' => {
        'type' => 'equals',
        'value' => 1
      }
    }
    results = metrics.custom(cfg)
    expect(results).to include('source' => 'node-exporter2:9100', 'value' => '1')
  end

  it '.custom_with_ip_address' do
    cfg = {
      'name' => 'heartbeat',
      'query' => 'up',
      'check' => {
        'type' => 'equals',
        'value' => 1
      }
    }
    results = metrics.custom(cfg)
    expect(results).to include('source' => '10.100.0.239:9100', 'value' => '1')
  end

  context '.disk' do
    it 'checks the disk usage with a default name for a root partition' do
      cfg = { 'mount' => '/' }
      results = metrics.disk(cfg)
      expect(results).to include('source' => 'node-exporter1:9100',
                                 'value' => 18,
                                 'name' => 'disk_root')
    end
    it 'checks the disk usage with an overridden name' do
      cfg = { 'mount' => '/',
              'name' => 'override_name' }
      results = metrics.disk(cfg)
      expect(results).to include('source' => 'node-exporter1:9100',
                                 'value' => 18,
                                 'name' => 'disk_override_name')
    end
    it 'checks the disk with a custom name' do
      cfg = { 'mount' => '/var/lib/docker',
              'name' => 'docker' }
      results = metrics.disk(cfg)
      expect(results).to include('source' => 'node-exporter1:9100',
                                 'value' => 29,
                                 'name' => 'disk_docker')
    end
  end

  context '.disk_all' do
    it 'checks the disk percentage usage' do
      cfg = { 'ignore_fs' => 'tmpfs' }
      results = metrics.disk_all(cfg)
      expect(results).to include('output' => 'Disk: /var/lib/docker, Usage: 29% |disk=29',
                                 'name' => 'disk_var_lib_docker',
                                 'value' => 29,
                                 'source' => 'node-exporter3:9100')
      expect(results).to include('output' => 'Disk: /usr, Usage: 67% |disk=67',
                                 'name' => 'disk_usr',
                                 'value' => 67,
                                 'source' => 'node-exporter3:9100')
    end
    it 'checks the inode percentage usage' do
      cfg = { 'ignore_fs' => 'tmpfs' }
      results = metrics.disk_all(cfg)
      expect(results).to include('output' => 'Inode: /var/lib/docker, Usage: 8% |inode=8',
                                 'name' => 'inode_var_lib_docker',
                                 'value' => 8,
                                 'source' => 'node-exporter3:9100')
      expect(results).to include('output' => 'Inode: /usr, Usage: 5% |inode=5',
                                 'name' => 'inode_usr',
                                 'value' => 5,
                                 'source' => 'node-exporter3:9100')
    end
  end

  context '.inode' do
    it 'checks the inode count with a custom name' do
      cfg = { 'mount' => '/usr', 'name' => 'custom_name_usr' }
      results = metrics.inode(cfg)
      expect(results).to include('name' => 'inode_custom_name_usr', 'source' => 'node-exporter1:9100', 'value' => 5)
    end
    it 'checks the inogre count with a default generated name' do
      cfg = { 'mount' => '/usr' }
      results = metrics.inode(cfg)
      expect(results).to include('name' => 'inode_usr', 'source' => 'node-exporter1:9100', 'value' => 5)
    end
  end

  context '.predict_disk_all' do
    it 'predicts that the disk will not fill up within 30 days' do
      cfg = {
        'days' => '30',
        'filter' => '{mountpoint="/var/lib/docker"}',
        'source' => 'test123'
      }
      results = metrics.predict_disk_all(cfg)
      expect(results).to include('output' => 'No disks are predicted to run out of space in the next 30 days',
                                 'name' => 'predict_disk_all',
                                 'status' => 0,
                                 'source' => 'test123')
    end
    it 'predicts the disk will fill up within 1 day' do
      cfg = {
        'days' => '1',
        'filter' => '{mountpoint="/var/lib/docker"}',
        'source' => 'test123'
      }
      results = metrics.predict_disk_all(cfg)
      expect(results).to include('output' => 'Disks predicted to run out of space in the next 1 days: node-exporter1:9100:/var/lib/docker',
                                 'name' => 'predict_disk_all',
                                 'status' => 1,
                                 'source' => 'test123')
    end
  end

  context '.service' do
    it 'checks if the service is running' do
      cfg = { 'name' => 'running.service' }
      results = metrics.service(cfg)
      expect(results).to include('source' => 'node-exporter1:9100',
                                 'value' => 1,
                                 'name' => 'service_running.service',
                                 'output' => 'Service: running.service (active=1)',
                                 'status' => 0)
    end
    it 'fails if the service is not running' do
      cfg = { 'name' => 'not_running.service' }
      results = metrics.service(cfg)
      expect(results).to include('source' => 'node-exporter1:9100',
                                 'value' => 0,
                                 'name' => 'service_not_running.service',
                                 'output' => 'Service: not_running.service (active=0)',
                                 'status' => 2)
    end
    it 'can check that a service is not running' do
      cfg = { 'name' => 'not_running.service', 'state_required' => 0 }
      results = metrics.service(cfg)
      expect(results).to include('source' => 'node-exporter1:9100',
                                 'value' => 0,
                                 'name' => 'service_not_running.service',
                                 'output' => 'Service: not_running.service (active=0)',
                                 'status' => 0)
    end
  end

  it '.load_per_cluster' do
    cfg = { 'cluster' => 'prometheus', 'source' => 'test' }
    results = metrics.load_per_cluster(cfg)
    expect(results).to include('source' => cfg['source'], 'value' => 0.15, 'name' => 'prometheus_load')
  end

  it '.load_per_cluster_minus_n' do
    cfg = { 'cluster' => 'prometheus', 'minus_n' => '1', 'source' => 'test' }
    results = metrics.load_per_cluster_minus_n(cfg)
    expect(results).to include('source' => 'test', 'value' => 0.22, 'name' => 'prometheus_load_minus_n')
  end

  it '.load_per_cpu' do
    results = metrics.load_per_cpu({})
    expect(results).to include('source' => 'node-exporter2:9100', 'value' => 0.15, 'name' => 'load')
  end

  it '.memory' do
    results = metrics.memory({})
    expect(results).to include('source' => 'node-exporter2:9100', 'value' => 29, 'name' => 'memory')
  end

  it '.memory_per_cluster' do
    cfg = { 'cluster' => 'prometheus', 'source' => 'test' }
    results = metrics.memory_per_cluster(cfg)
    expect(results).to include('source' => cfg['source'], 'value' => 33.7, 'name' => 'prometheus_memory')
  end
  context '.nice_disk_name' do
    it 'creates a nice readable disk name' do
      expect(metrics.send(:nice_disk_name, '/var/lib/docker')).to eql('var_lib_docker')
    end
    it 'ignores trailing slashes in the disk name' do
      expect(metrics.send(:nice_disk_name, '/var/lib/docker/')).to eql('var_lib_docker')
    end
    it 'handles gives root disks a nice name too' do
      expect(metrics.send(:nice_disk_name, '/')).to eql('root')
    end
  end
end
