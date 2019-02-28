require "active_support/inflector"

module TopologicalInventory
  module MockSource
    class Parser
      attr_accessor :collections, :resource_timestamp

      delegate :add_collection, :to => :collections

      def initialize
        @collections = TopologicalInventoryIngressApiClient::Collector::InventoryCollectionStorage.new

        self.resource_timestamp = Time.now.utc
      end

      def lazy_find(collection, reference, ref: :manager_ref)
        TopologicalInventoryIngressApiClient::InventoryObjectLazy.new(
          :inventory_collection_name => collection,
          :reference                 => reference,
          :ref                       => ref,
        )
      end
    end
  end
end
