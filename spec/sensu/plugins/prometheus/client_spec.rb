require 'spec_helper'

describe Sensu::Plugins::Prometheus::Client, :vcr do
  let(:client) { Sensu::Plugins::Prometheus::Client.new }

  it 'instantiates a Prometheus Client class' do
    expect(client).to be_a(Sensu::Plugins::Prometheus::Client)
  end

  it '.percent_query_free: creates a prometheus query' do
    total = 'total_something{hello="world"}'
    available = 'available_something{world="hello"}'
    expect(client.percent_query_free(total, available)).to eq(
      '100-((available_something{world="hello"}/total_something{hello="world"})*100)'
    )
  end

  it '.percent_query_free: accurately calculates the percentage free' do
    total = '100'
    available = '30'
    result = client.query(client.percent_query_free(total, available))
    expect(result[1]).to eq('70')
  end

  it '.query: raises an error when it prometheus cannot be queried' do
    begin
      prom_endpoint_temp = ENV['PROMETHEUS_ENDPOINT']
      ENV['PROMETHEUS_ENDPOINT'] = '127.0.0.1:9999'
      expect { client.query('up') }.to raise_error(RuntimeError)
    ensure
      ENV['PROMETHEUS_ENDPOINT'] = prom_endpoint_temp
    end
  end

  it '.query: return nothing if no results are returned' do
    expect(client.query('up')).to eql(nil)
  end
end
