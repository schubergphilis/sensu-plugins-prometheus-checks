require 'erb'
require 'ostruct'

require 'sensu/plugins/prometheus/checks/namespace'

module Sensu
  module Plugins
    module Prometheus
      module Checks
        # Handles the final output of checks, creates a custom message based on
        # template and informed variables.
        class Output
          TEMPLATES = {
            'disk' => \
              "Disk: <%= value %>%, Mountpoint: <%= cfg['mount'] %> |disk=<%= value %>",
            'disk_all' => \
              "Disk: <%= cfg['mount'] %>, Inode Usage: <%= value %>% |inodes=<%= value %>",
            'load_per_cpu' => \
              'Load: <%= value %>|load=<%= value %>',
            'load_per_cluster' => \
              'Cluster Load: <%= value %> |load=<%= value %>',
            'load_per_cluster_minus_n' => \
              'Cluster Load: <%= value %> |load=<%= value %>',
            'inode' => \
              "Disk: <%= cfg['mount'] %>, Inodes: <%= value %>% |inodes=<%= value %>",
            'memory' => \
              'Memory <%= value %>% |memory=<%= value %>',
            'memory_per_cluster' => \
              'Cluster Memory: <%= value %>% |memory=<%= value %>"',
            'service' => \
              "Service: <%= cfg['name'] %> (<%= cfg['state'] %>=<%= value %>)"
          }.freeze

          def render(template_name, vars)
            template_name = template_name.to_s
            raise "Can't find template for '#{template_name}'" \
              if !TEMPLATES.key?(template_name) || TEMPLATES[template_name].empty?
            ns = Sensu::Plugins::Prometheus::Checks::Namespace.new(vars)
            ERB.new(TEMPLATES[template_name]).result(ns.namespace_binding)
          end
        end
      end
    end
  end
end
