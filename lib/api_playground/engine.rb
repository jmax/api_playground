module ApiPlayground
  class Engine < ::Rails::Engine
    isolate_namespace ApiPlayground

    initializer "api_playground.action_dispatch" do
      ActiveSupport.on_load(:action_controller) do
        include ApiPlayground::ApiProtection
      end
    end

    initializer "api_playground.routing_mapper", before: :set_routes_reloader do
      ActionDispatch::Routing::Mapper.include(ApiPlayground::RoutingMapper)
    end

    initializer "api_playground.table_name_prefix" do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.include(Module.new do
          def self.included(base)
            base.before_create { self.class.table_name_prefix = "api_playground_" }
          end
        end)
      end
    end
  end
end 