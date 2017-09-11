require 'sensu/plugins/utils/log'
require 'sensu/plugins/prometheus/checks'

module Sensu
  module Plugins
    module Prometheus
      # Represents the queryies that will be fired against Prometheus to collect
      # information about monitored resources. Ideally all public methods on
      # this class will be available as a final check.
      class Metrics
        include Sensu::Plugins::Utils::Log
        include Sensu::Plugins::Prometheus::Checks

        def initialize(prometheus_client)
          @client = prometheus_client
        end

        # Execute query informed on check's configuration and makes no
        # modifications on value.
        def custom(cfg)
          metrics = []
          @client.query(cfg['query']).each do |result|
            source = if result['metric'].key? 'app'
                       result['metric']['app']
                     else
                       result['metric']['instance']
                     end

            metrics << {
              'source' => source,
              'value' => result['value'][1]
            }
          end
          metrics
        end

        # Query percentage of mountpoint total disk space size compared with
        # avaiable.
        def disk(cfg)
          mountpoint = "mountpoint=\"#{cfg['mount']}\""
          disk_name = cfg['name'] || nice_disk_name(cfg['mount'])
          query = @client.percent_query_free(
            "node_filesystem_size{#{mountpoint}}",
            "node_filesystem_avail{#{mountpoint}}"
          )
          prepare_metrics("disk_#{disk_name}", @client.query(query))
        end

        # Query percentage of free space on file-systems, ignoring by default
        # `tmpfs` or the regexp configured on check.
        def disk_all(cfg)
          results = []
          ignored = cfg['ignore_fs'] || 'tmpfs'
          ignore_fs = "fstype!~\"#{ignored}\""

          queries = [
            {
              'used' => 'node_filesystem_size',
              'free' => 'node_filesystem_avail',
              'name' => 'disk'
            },
            {
              'used' => 'node_filesystem_files',
              'free' => 'node_filesystem_files_free',
              'name' => 'inode'
            }
          ]
          queries.each do |q|
            query = @client.percent_query_free(
              "#{q['used']}{#{ignore_fs}}",
              "#{q['free']}{#{ignore_fs}}"
            )
            @client.query(query).each do |result|
              hostname = result['metric']['instance']
              mountpoint = result['metric']['mountpoint']
              disk_name = nice_disk_name(mountpoint)
              percent = result['value'][1].to_i
              results << { 'output' => "#{q['name'].capitalize}: #{mountpoint}, Usage: #{percent}% |#{q['name']}=#{percent}",
                           'name' => "#{q['name']}_#{disk_name}",
                           'value' => percent,
                           'source' => hostname }
            end
          end
          results
        end

        # Queyr percentage of free inodes on check's configured mountpoint.
        def inode(cfg)
          mountpoint = "mountpoint=\"#{cfg['mount']}\""
          disk_name = cfg['name'] || nice_disk_name(cfg['mount'])
          query = @client.percent_query_free(
            "node_filesystem_files{#{mountpoint}}",
            "node_filesystem_files_free{#{mountpoint}}"
          )
          prepare_metrics("inode_#{disk_name}", @client.query(query))
        end

        # Compose query to predict disk usage on the last day.
        def predict_disk_all(cfg)
          disks = []
          days = cfg['days'].to_i
          days_in_seconds = days.to_i * 86_400
          filter = cfg['filter'] || {}
          range_vector = cfg['sample_size'] || '24h'
          exit_code = cfg['exit_code'] || 1
          query = format(
            'predict_linear(node_filesystem_avail%s[%s], %i) < 0',
            filter,
            range_vector,
            days_in_seconds
          )
          @client.query(query).each do |result|
            hostname = result['metric']['instance']
            disk = result['metric']['mountpoint']
            disks << "#{hostname}:#{disk}"
          end

          if disks.empty?
            [{ 'status' => 0,
               'output' => "No disks are predicted to run out of space in the next #{days} days",
               'name' => 'predict_disk_all',
               'source' => cfg['source'] }]
          else
            disks = disks.join(',')
            [{ 'status' => exit_code.to_i,
               'output' => "Disks predicted to run out of space in the next #{days} days: #{disks}",
               'name' => 'predict_disk_all',
               'source' => cfg['source'] }]
          end
        end

        # Service metrics will contain it's "state" as "value".
        def service(cfg)
          results = []
          defaults = {
            'state' => 'active',
            'state_required' => 1
          }
          cfg = defaults.merge(cfg)
          query = format(
            "node_systemd_unit_state{name='%s',state='%s'}",
            cfg['name'], cfg['state']
          )
          prepare_metrics("service_#{cfg['name']}", @client.query(query)).each do |metric|
            metric['status'] = equals(metric['value'], cfg['state_required'])
            metric['output'] = "Service: #{cfg['name']} (#{cfg['state']}=#{metric['value']})"
            results << metric
          end
          results
        end

        # Query the percentage free memory.
        def memory(_)
          query = @client.percent_query_free(
            'node_memory_MemTotal',
            'node_memory_MemAvailable'
          )
          prepare_metrics('memory', @client.query(query))
        end

        # Percentage free memory cluster wide.
        def memory_per_cluster(cfg)
          cluster = cfg['cluster']
          query = @client.percent_query_free(
            "sum(node_memory_MemTotal{job=\"#{cluster}\"})",
            "sum(node_memory_MemAvailable{job=\"#{cluster}\"})"
          )

          metrics = []
          source = cfg['source']
          @client.query(query).each do |result|
            value = result['value'][1].to_f.round(2)
            log.debug("[memory_per_cluster] value: '#{value}', source: '#{source}'")
            metrics << { 'source' => source, 'value' => value, 'name' => "#{cluster}_memory" }
          end
          metrics
        end

        # Calculates the load of an entire cluster.
        def load_per_cluster(cfg)
          cluster = cfg['cluster']
          query = format(
            'sum(node_load5{job="%s"})/count(node_cpu{mode="system",job="%s"})',
            cluster,
            cluster
          )

          result = @client.query(query).first
          source = cfg['source']
          value = result['value'][1].to_f.round(2)
          log.debug(
            "[load_per_cluster] value: '#{value}', source: '#{source}'"
          )

          [{ 'source' => source, 'value' => value, 'name' => "#{cluster}_load" }]
        end

        # Returns a single metric entry, with the sum of the total load on
        # cluster divided by the total amount of CPUs.
        def load_per_cluster_minus_n(cfg)
          cluster = cfg['cluster']
          minus_n = cfg['minus_n']
          sum_load = "sum(node_load5{job=\"#{cluster}\"})"
          total_cpus = "count(node_cpu{mode=\"system\",job=\"#{cluster}\"})"
          total_nodes = "count(node_load5{job=\"#{cluster}\"})"

          query = format(
            '%s/(%s-(%s/%s)*%d)',
            sum_load, total_cpus, total_cpus, total_nodes, minus_n
          )
          result = @client.query(query).first
          value = result['value'][1].to_f.round(2)
          source = cfg['source']
          log.debug(
            "[load_per_cluster_minus_n] value: '#{value}', source: '#{source}'"
          )

          [{ 'source' => source, 'value' => value, 'name' => "#{cluster}_load_minus_n" }]
        end

        # Current load per CPU.
        def load_per_cpu(_)
          cpu_per_source = {}
          @client.query(
            '(count(node_cpu{mode="system"})by(instance))'
          ).each do |result|
            source = result['metric']['instance']
            cpu_per_source[source] = result['value'][1]
          end

          metrics = []
          @client.query('node_load5').each do |result|
            source = result['metric']['instance']
            value = result['value'][1].to_f.round(2)
            load_on_cpu = value / cpu_per_source[source].to_f
            log.debug(
              "[load_per_cpu] value: '#{load_on_cpu}', source: '#{source}'"
            )
            metrics << {
              'source' => source,
              'value' => load_on_cpu,
              'name' => 'load'
            }
          end
          metrics
        end

        private

        # Prepare metrics with integer valutes, the most common case in the class.
        def prepare_metrics(metric_name, results)
          metrics = []
          results.each do |result|
            source = result['metric']['instance']
            value = result['value'][1].to_i
            log.debug("[#{metric_name}] value: '#{value}', source: '#{source}'")
            metrics << { 'name' => metric_name, 'source' => source, 'value' => value }
          end
          metrics
        end

        def nice_disk_name(disk)
          if disk == '/'
            'root'
          else
            disk.gsub(%r{^/}, '').gsub(%r{/$}, '').gsub(%r{/}, '_')
          end
        end
      end
    end
  end
end
