module Sensu
  module Plugins
    module Prometheus
      # Static methods to help on a given check evaluation. This module is
      # designed to be included where the check evaluation will happen.
      module Checks
        # Given current result, warning and critical levels, it will return a
        # integer with the current level, zero is success.
        def evaluate(result, warn, crit)
          # If no result was given return an unknown since converting nil to a float gives 0.0 :(
          return 3 if result.nil?

          result = result.to_f
          warn = warn.to_f
          crit = crit.to_f

          status = 3
          if result < warn
            status = 0
          elsif result >= crit
            status = 2
          elsif result >= warn
            status = 1
          end

          status
        end

        # Return zero if result and value are the same.
        def equals(result, value)
          status = 2
          status = 0 if result.to_f == value.to_f
          status
        end

        # Return zero if result is below value.
        def below(result, value)
          status = 2
          status = 0 if result.to_f < value.to_f
          status
        end

        # Return zero if result is above value.
        def above(result, value)
          status = 2
          status = 0 if result.to_f > value.to_f
          status
        end
      end
    end
  end
end
