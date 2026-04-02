# frozen_string_literal: true

module IntToUuid
  class IntegerId
    ID_MIN = 0
    ID_MAX = 2**63 - 1       # 9223372036854775807
    NAMESPACE_MIN = 0
    NAMESPACE_MAX = 2**32 - 1 # 4294967295

    attr_reader :value, :namespace

    def initialize(value, namespace: 0)
      unless value.is_a?(Integer) && value >= ID_MIN && value <= ID_MAX
        raise ArgumentError, "value must be an integer between #{ID_MIN} and #{ID_MAX}, got #{value.inspect}"
      end
      unless namespace.is_a?(Integer) && namespace >= NAMESPACE_MIN && namespace <= NAMESPACE_MAX
        raise ArgumentError, "namespace must be an integer between #{NAMESPACE_MIN} and #{NAMESPACE_MAX}, got #{namespace.inspect}"
      end

      @value = value
      @namespace = namespace
    end
  end
end
