require 'sensu/plugins/utils/log'
require 'sensu/plugins/events/dispatcher'
require 'sensu/plugins/prometheus/client'
require 'sensu/plugins/prometheus/metrics'
require 'sensu/plugins/prometheus/checks'
require 'sensu/plugins/prometheus/checks/output'

module Sensu
  module Plugins
    module Prometheus
      module Checks
        # Execute the configured checks, evaluate the results and set a final
        # output and status.
        class Runner
          include Sensu::Plugins::Utils::Log
          include Sensu::Plugins::Prometheus::Checks

          attr_reader :status, :output, :events

          # Does basic configuration validation and start the object the methods
          # on this class will consume.
          def initialize(config)
            raise 'Configuration is empty, abort!' \
              if config.nil? || config.empty?
            raise "Configuration does not specify 'config' section!" \
              unless config.key?('config')

            config['checks'] = [] unless config.key?('checks')
            config['custom'] = [] unless config.key?('custom')

            @config = config
            @events = []
            @status = 0
            @output = ''
            @source_nodename_map = nil

            @prometheus = Sensu::Plugins::Prometheus::Client.new
            @metrics =  Sensu::Plugins::Prometheus::Metrics.new(@prometheus)
            @tmpl = Sensu::Plugins::Prometheus::Checks::Output.new
            @dispatcher = Sensu::Plugins::Events::Dispatcher.new
          end

          # Drives the evaluation of regular and custom checks, then calls for
          # the final analysis on collected events.
          def run
            evaluate_checks if @config.key?('checks')
            evaluate_custom if @config.key?('custom')
            evaluate_and_dispatch_events
          end

          private

          # Wrap around Metrics object and capture exception.
          def collect_metrics(name, check_cfg)
            metrics = []
            begin
              # invoke method name method on metric object
              metrics = @metrics.send(name, check_cfg)
            # :nocov:
            rescue NoMethodError => e
              log.error(
                "Method '#{name}' is not present on Metrics object: '#{e}'"
              )
            end
            # :nocov:
            metrics
          end

          # Apply evaluation to all pre-defined checks.
          def evaluate_checks
            log.info("Evaluating Checks: '#{@config['checks'].length}'")

            @config['checks'].each do |check|
              check_name = check['check']
              check_cfg = check['cfg']

              collect_metrics(check_name, check_cfg).each do |metric|
                status = 0

                # on service it will come with "state_required" flag
                if check_name == 'service'
                  # adding defaults in case they are not set
                  check_cfg = check_cfg.merge(
                    'state' => 'active',
                    'state_required' => 1
                  )
                  # giving a service hint by adding it's name
                  check_name = "service_#{check_cfg['name']}"
                  status = equals(metric['value'], check_cfg['state_required'])
                else
                  # normal threshold evaluation
                  status = evaluate(
                    metric['value'],
                    check_cfg['warn'],
                    check_cfg['crit']
                  )
                end

                template_variables = metric
                template_variables['cfg'] = check_cfg

                append_event(
                  "check_#{check_name}",
                  @tmpl.render(check['check'], template_variables),
                  status,
                  metric['source']
                )
              end
            end
          end

          # Apply checks based on custom Prometheus queries and custom check
          # config.
          def evaluate_custom
            log.info("Evaluating Custom: '#{@config['custom'].length}'")

            @config['custom'].each do |custom|
              # invoke "custom" method in metrics object
              collect_metrics('custom', custom).each do |metric|
                value = metric['value']
                name = custom['name']

                if custom.key?('check') && !custom['check']['type'].empty?
                  # calling local method to determine metric status
                  status = send(
                    custom['check']['type'],
                    value,
                    custom['check']['value']
                  )
                elsif custom.key?('cfg')
                  # normal threshold evaluation
                  status = evaluate(
                    value,
                    custom['cfg']['warn'],
                    custom['cfg']['crit']
                  )
                else
                  log.warn(
                    "Custom check does not have 'check' or 'cfg', can't be evaluated"
                  )
                  status = 3
                end

                log.debug("Custom Check: name='#{name}', value='#{value}'")

                # making sure the custom check has the status defined
                output = if custom['msg'].key?(status)
                           custom['msg'][status].to_s
                         else
                           'No output message defined for this check'
                         end

                append_event(
                  name,
                  output,
                  status,
                  metric['source'] || '<<UNKNOWN_SOURCE>>'
                )
              end
            end
          end

          # Classify and select whitelisted events to dispatch. Also prepares
          # the final status and output message.
          def evaluate_and_dispatch_events
            non_successful_events = []

            @events.reverse_each do |event|
              # skipping events that are not whitelisted
              if @config['config'].key?('whitelist') && event['source'] !~ /#{@config['config']['whitelist']}/
                @events.delete(event)
                log.debug(
                  "Skipping event! Source '#{event['source']}' does not " \
                    "match /#{@config['config']['whitelist']}/"
                )
                next
              end
              # removing source key to use local's sensu source name (hostname)
              if @config.key?('config') && \
                 @config['config'].key?('use_default_source') && \
                 @config['config']['use_default_source']
                log.debug("Removing 'source' from event, using Sensu's default")
                event.delete('source')
              end
              # selecting the non-succesful events
              non_successful_events << event if event['status'] != 0
              # dispatching event to Sensu
              @dispatcher.dispatch(event)
            end

            # setting up final status and output message
            amount_checks = @config['checks'].length + @config['custom'].length
            amount_events = @events.length

            if non_successful_events.empty?
              @status = 0
              @output = \
                "OK: Ran #{amount_checks} checks succesfully on #{amount_events} events!"
            else
              log.debug("#{non_successful_events.length} failed events")
              @status = 1
              non_successful_events.sort_by { |e| e['status'] } .reverse.each do |event|
                @output << ' | ' unless @output.empty?
                @output << "Source: #{event['source']}, " \
                  "Check: #{event['name']}, " \
                  "Output: #{event['output']}, " \
                  "Status: #{event['status']}"
              end
            end

            log.debug("Ran #{amount_checks}, and collected #{amount_events} events")
            log.debug("Final Status: #{@status}")
            log.debug("Final Output: #{@output}")
          end

          # Query Prometheus to discover the nodenames per instance, found on
          # the last day, and sanitize query events into a hash, returned by
          # this method.
          def source_nodename_map
            map = {}
            @prometheus.query('max_over_time(node_uname_info[1d])').each do |result|
              source = result['metric']['instance']
              nodename = result['metric']['nodename'].split('.', 2)[0]
              log.info("[node_exporter] instance: '#{source}', nodename: '#{nodename}'")
              map[source] = nodename
            end
            log.warn('Unable to query the node_exporter instances from Prometheus') \
              if map.empty?
            map
          end

          # Remove chars that are not allowed in Sensu.
          def sensu_safe(string)
            string.gsub(/[^\w\.-]+/, '_')
          end

          # Append an event on the pool, making string safe for Sensu, checking
          # "source" against "source_nodename_map" and composing "address" using
          # configuration "domain" entry.
          def append_event(name, output, status, source)
            log.info(
              "[#{status}] check: '#{name}', output: '#{output}', source: '#{source}'"
            )

            # let source-nodename mapping avialable
            @source_nodename_map = source_nodename_map \
              if @source_nodename_map.nil?

            # translating node_exporter hostname into nodename plus domain
            nodename = @source_nodename_map[source] || source
            address = "#{nodename}.#{@config['config']['domain']}"

            @events << {
              'address' => sensu_safe(address),
              'name' => sensu_safe(name),
              'occurrences' => @config['config']['occurrences'] || 1,
              'output' => output,
              'reported_by' => @config['config']['reported_by'],
              'status' => status,
              'source' => sensu_safe(nodename)
            }
          end
        end
      end
    end
  end
end
