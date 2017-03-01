require 'logger'

module Sensu
  module Plugins
    module Utils
      # Helper class to handle application logging. To be included in other
      # classes and referenced by `log`.
      module Log
        def log
          Log.log
        end

        # Creates a new logger instance a single time and set the log level. The
        # level is determined by 'PROM_DEBUG' environment variable, when set the
        # logger will use `0` (DEEBUG) otherwise `1` (INFO).
        def self.log
          @log ||= Logger.new(STDOUT)
          @log.level = 1 if @log && !ENV.key?('PROM_DEBUG')
          @log
        end
      end
    end
  end
end
