Gem::Specification.new do |gem|
  gem.name    = 'sensu-plugins-prometheus-checks'
  gem.version = '0.0.7'
  gem.date    = Date.today.to_s
  gem.summary = "Sensu plugin for monitoring servers by querying prometheus"
  gem.description = "Sensu plugin for monitoring servers by querying prometheus"
  gem.authors  = ['Michael Russell']
  gem.email    = 'mrussell@schubergphilis.com'
  gem.homepage = 'https://sbp.gitlab.schubergphilis.com/saas/sensu-plugins-prometheus-checks'
  gem.add_development_dependency('rspec', [">= 3.5.0"])
  gem.executables = ['check_prometheus.rb']
end
