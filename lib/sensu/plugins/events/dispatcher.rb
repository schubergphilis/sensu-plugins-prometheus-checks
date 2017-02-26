require 'json'
require 'socket'
require 'sensu/plugins/utils/log'

module Sensu
  module Plugins
    module Events
      # Helper class to dispatch events into Sensu socket.
      class Dispatcher
        include Sensu::Plugins::Utils::Log

        def initialize
          @sensu_address = '127.0.0.1'
          @sensu_port = 3030
          read_env_address_and_port

          log.debug("Sensu at '#{@sensu_address}':'#{@sensu_port}'")
        end

        # Send accumulated events into Sensu's socket, unless environment
        # variable PROM_DEBUG is set.
        def dispatch(event)
          if ENV.key?('PROM_DEBUG')
            log.debug("PROM_DEBUG set, not dispatching event to Sensu: #{event}")
            return
          end

          begin
            s = TCPSocket.open(@sensu_address, @sensu_port)
            s.puts(JSON.generate(event))
            s.close
          rescue SystemCallError => e
            log.error("Sensu is refusing connections! Error: '#{e}'")
            raise("Sensu is not avilable at '#{@sensu_address}:#{@sensu_port}'")
          end
        end

        private

        # Read Sensu address and port from environment.
        def read_env_address_and_port
          @sensu_address = ENV['SENSU_SOCKET_ADDRESS'] \
            if ENV.key?('SENSU_SOCKET_ADDRESS')
          @sensu_port = ENV['SENSU_SOCKET_PORT'].to_i \
            if ENV.key?('SENSU_SOCKET_PORT')
        end
      end
    end
  end
end
