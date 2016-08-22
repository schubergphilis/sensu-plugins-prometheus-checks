require_relative '../check_prometheus'

require 'rspec/expectations'

def slice(hash, *keys)
  Hash[ [keys, hash.values_at(*keys)].transpose]
end

RSpec::Matchers.define :include_hash_matching do |expected|
  match do |array_of_hashes|
    array_of_hashes.any? { |element| slice(element, *expected.keys) == expected }
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
    expect(results).to include_hash_matching('output' => 'Memory 36%|memory=36', 'source' => 'node-exporter1:9100')
    expect(results).to include_hash_matching('output' => 'Memory 41%|memory=41', 'source' => 'node-exporter2:9100')
    expect(results).to include_hash_matching('output' => 'Memory 41%|memory=41', 'source' => 'node-exporter3:9100')
  end
end


