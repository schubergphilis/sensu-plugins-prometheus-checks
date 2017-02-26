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
end
