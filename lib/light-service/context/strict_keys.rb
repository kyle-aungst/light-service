module LightService
  class Context
    # Added to a context the first time an action runs with strict keys on.
    # While an executed block runs, reading or writing a key the action doesn't
    # declare raises; outside executed blocks nothing is checked
    module StrictKeys
      # Set and read by organizers
      INTERNAL_KEYS = %i[_aliases _before_actions _after_actions].freeze

      %i[[] fetch key? has_key? include? member? delete dig].each do |name|
        define_method(name) do |key, *args, &block|
          verify_declared_key(key)
          super(key, *args, &block)
        end
      end

      %i[[]= store].each do |name|
        define_method(name) do |key, value|
          verify_declared_key(key)
          super(key, value)
        end
      end

      %i[values_at fetch_values].each do |name|
        define_method(name) do |*keys, &block|
          keys.each { |key| verify_declared_key(key) }
          super(*keys, &block)
        end
      end

      %i[merge! update].each do |name|
        define_method(name) do |*others, &block|
          others.each do |other|
            other.to_hash.each_key { |key| verify_declared_key(key) }
          end
          super(*others, &block)
        end
      end

      private

      def verify_declared_key(key)
        return if @restricted_keys.nil? || @restricted_keys.include?(key)
        return if INTERNAL_KEYS.include?(key)

        raise UndeclaredKeyError,
              "#{@restricted_action} used #{key.inspect} without declaring " \
              "it with expects, promises or allows"
      end
    end
  end
end
