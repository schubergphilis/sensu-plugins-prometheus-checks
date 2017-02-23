# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'sensu/plugins/prometheus/checks/version'

Gem::Specification.new do |spec|
  spec.name = 'sensu-plugins-prometheus-checks'
  spec.version = Sensu::Plugins::Prometheus::Checks::VERSION
  spec.authors = ['Michael Russell', 'Otávio Fernandes']
  spec.email = ['mrussell@schubergphilis.com', 'ofernandes@schubergphilis.com']

  spec.summary = 'Sensu plugin for monitoring servers by querying Prometheus'
  spec.description = 'Sensu plugin to compose complex Prometheus queries and ' \
    'execute result-set evaluation'
  spec.homepage = 'https://sbp.gitlab.schubergphilis.com/saas/sensu-plugins-prometheus-checks'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'rspec', '~> 3.5'
  spec.add_development_dependency 'rubocop', '~> 0.47'
  spec.add_development_dependency 'simplecov', '~> 0.13'
  spec.add_development_dependency 'vcr', '~> 3.0'
  spec.add_development_dependency 'webmock', '~> 2.3.2'

  spec.add_dependency 'kubeclient', '~> 2.3'
end
