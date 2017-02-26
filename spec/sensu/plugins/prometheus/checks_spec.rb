require 'spec_helper'

describe Sensu::Plugins::Prometheus::Checks do
  include Sensu::Plugins::Prometheus::Checks

  it 'has a version number' do
    expect(Sensu::Plugins::Prometheus::Checks::VERSION).not_to be nil
  end

  it '#evaluate' do
    expect(evaluate(1, 2, 3)).to equal(0)
    expect(evaluate(3, 4, 5)).to equal(0)
    expect(evaluate(4.1, 4, 5)).to equal(1)
    expect(evaluate(6, 4, 5)).to equal(2)
  end

  it '#equals' do
    expect(equals(1, 1)).to equal(0)
    expect(equals(1, 2)).to equal(2)
  end
end
