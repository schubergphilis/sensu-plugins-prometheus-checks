module Sensu
  module Plugins
    module Prometheus
      module Checks
        # Helper to transform a hash into local methods.
        class Namespace
          def initialize(hash)
            hash.each do |key, value|
              singleton_class.send(:define_method, key) { value }
            end
          end

          # Wrap around `binding` method.
          def namespace_binding
            binding
          end
        end
      end
    end
  end
end
