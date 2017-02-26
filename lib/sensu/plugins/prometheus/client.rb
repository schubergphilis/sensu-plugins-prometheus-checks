require 'json'
require 'net/http'

require 'sensu/plugins/utils/log'

module Sensu
  module Plugins
    module Prometheus
      # Prometheus http-client, able to query and validate results.
      class Client
        include Sensu::Plugins::Utils::Log

        # Instantiates the http-client with `prometheus_endpoint`.
        def initialize
          host, port = prometheus_endpoint.split(':')
          log.info("Prometheus at '#{host}':'#{port}'")
          @client = Net::HTTP.new(host, port)
          @client.read_timeout = 3
          @client.open_timeout = 3
        end

        # Execute query on Prometheus and validate payload. When successful it
        # will return payload inner `result`, otherwise nil.
        def query(prometheus_query)
          log.debug("Prometheus Query: '#{prometheus_query}'")
          prometheus_query = CGI.escape(prometheus_query)

          begin
            get_request = Net::HTTP::Get.new("/api/v1/query?query=#{prometheus_query}")
            response_body = @client.request(get_request).body
          rescue SystemCallError => e
            log.error("Communication error with Prometheus: '#{e}'")
            raise "Can't send query to Prometheus!"
          end

          payload = JSON.parse(response_body)
          if !payload.key?('data') || !payload['data'].key?('result')
            log.error("Can't find 'data' and/or 'result' keys on query result!")
            return nil
          end
          payload['data']['result']
        end

        # String placeholders to calculate percentage free.
        def percent_query_free(total, available)
          "100-((#{available}/#{total})*100)"
        end

        private

        # Reads `PROMETHEUS_ENDPOINT` from environment or use default localhost,
        # applies validation to make sure ':' is present.
        def prometheus_endpoint
          endpoint = ENV['PROMETHEUS_ENDPOINT'] || '127.0.0.1:9090'
          raise "Invalid endpoint 'PROMETHEUS_ENDPOINT=" + endpoint + "'" \
            unless endpoint.include?(':')
          endpoint
        end
      end
    end
  end
end
