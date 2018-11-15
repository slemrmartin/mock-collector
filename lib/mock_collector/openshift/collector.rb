require "config"
require "openshift/collector"
require "mock_collector/openshift/server"

module MockCollector
  module Openshift
    class Collector < ::Openshift::Collector
      def initialize(source, config: nil)
        path_to_config = File.expand_path("../../../config/openshift", File.dirname(__FILE__))
        ::Config.load_and_set_settings(File.join(path_to_config, "#{config}.yml"))

        super(source,
              nil,
              nil,
              :default_limit => (::Settings.default_limit || 1_000).to_i,
              :poll_time     => (::Settings.events&.check_interval || 5).to_i
        )
      end

      def collect!
        start_collector_threads

        until finished? do
          notices = []
          notices << queue.pop until queue.empty?

          targeted_refresh(notices) unless notices.empty?

          sleep(poll_time)
        end
      end

      def finished?
        some_thread_alive = entity_types.any? do |entity_type|
          collector_threads[entity_type] && collector_threads[entity_type].alive?
        end

        !some_thread_alive
      end

      def connection
        @connection ||= MockCollector::Openshift::Server.new
      end

      def connection_for_entity_type(_entity_type = nil)
        connection
      end

      def collector_thread(connection, entity_type)
        # Full refresh
        if %i(standard full_refresh).include?(::Settings.refresh_mode)
          (::Settings.full_refresh&.repeats_count || 1).to_i.times do
            full_refresh(connection, entity_type)
          end
        end

        # Stop if full refresh only
        return if ::Settings.refresh_mode == :full_refresh

        # Watching events (targeted refresh)
        if %i(standard events).include?(::Settings.refresh_mode)
          watch(connection, entity_type, nil) do |notice|
            log.info("#{entity_type} #{notice.object.metadata.name} was #{notice.type.downcase}")
            queue.push(notice)
          end
        end
      rescue => err
        log.error(err)
      end

      def watch(connection, entity_type, _resource_version, &block)
        connection.watch(entity_type, &block)
      end

      def entity_types
        case ::Settings.full_refresh.send_order
        when :normal then MockCollector::Openshift::Storage.entity_types
        when :reversed then MockCollector::Openshift::Storage.entity_types.reverse
        else raise "Send order :#{::Settings.send_order} of entity types unknown. Allowed values: :normal, :reversed"
        end
      end
    end
  end
end
