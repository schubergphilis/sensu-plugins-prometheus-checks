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

  it '.disk' do
    cfg = { 'mount' => '/', 'name' => 'root' }
    results = metrics.disk(cfg)
    expect(results).to include('source' => 'node-exporter1:9100', 'value' => 18)
  end

  it '.disk_all' do
    cfg = { 'ignore_fs' => 'tmpfs' }
    results = metrics.disk_all(cfg)
    expect(results).to include('source' => 'node-exporter3:9100', 'value' => 0)
  end

  it '.inode' do
    cfg = { 'mount' => '/usr', 'name' => 'usr' }
    results = metrics.inode(cfg)
    expect(results).to include('source' => 'node-exporter1:9100', 'value' => 5)
  end

  it '.predict_disk_all' do
    cfg = { 'days' => '30', 'filter' => '{mountpoint="/var/lib/docker"}' }
    results = metrics.predict_disk_all(cfg)
    expect(results).to be_empty
  end

  it '.service' do
    cfg = { 'name' => 'running.service' }
    results = metrics.service(cfg)
    expect(results).to include('source' => 'node-exporter1:9100', 'value' => 1)
  end

  it '.load_per_cluster' do
    cfg = { 'cluster' => 'prometheus', 'source' => 'test' }
    results = metrics.load_per_cluster(cfg)
    expect(results).to include('source' => cfg['source'], 'value' => 0.15)
  end

  it '.load_per_cluster_minus_n' do
    cfg = { 'cluster' => 'prometheus', 'minus_n' => '1', 'source' => 'test' }
    results = metrics.load_per_cluster_minus_n(cfg)
    expect(results).to include('source' => 'test', 'value' => 0.22)
  end

  it '.load_per_cpu' do
    results = metrics.load_per_cpu({})
    expect(results).to include('source' => 'node-exporter2:9100', 'value' => 0.15)
  end

  it '.memory' do
    results = metrics.memory({})
    expect(results).to include('source' => 'node-exporter2:9100', 'value' => 29)
  end

  it '.memory_per_cluster' do
    cfg = { 'cluster' => 'prometheus', 'source' => 'test' }
    results = metrics.memory_per_cluster(cfg)
    expect(results).to include('source' => cfg['source'], 'value' => 33.7)
  end
end
