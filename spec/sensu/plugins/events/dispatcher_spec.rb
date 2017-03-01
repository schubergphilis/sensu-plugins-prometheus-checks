require 'spec_helper'

describe Sensu::Plugins::Events::Dispatcher, :vcr do
  let(:dispatcher) { Sensu::Plugins::Events::Dispatcher.new }

  it 'instantiates a Dispatcher class' do
    expect(dispatcher).to be_a(Sensu::Plugins::Events::Dispatcher)
  end
end
