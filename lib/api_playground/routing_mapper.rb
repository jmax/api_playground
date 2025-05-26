module ApiPlayground
  module RoutingMapper
    # Defines a set of RESTful API routes for the playground functionality
    #
    # @example Basic usage with defaults (namespace: :api, source: :playground)
    #   api_playground_routes
    #   # => Creates routes under /api/playground/...
    #
    # @example Custom namespace
    #   api_playground_routes(namespace: :v1)
    #   # => Creates routes under /v1/playground/...
    #
    # @example Custom source controller
    #   api_playground_routes(source: :explorer)
    #   # => Creates routes under /api/explorer/... using ExplorerController
    #
    # @param [Hash] options The configuration options
    # @option options [Symbol] :namespace The namespace under which the routes will be created
    # @option options [Symbol] :source The base name for the controller and URL path
    def api_playground_routes(options = {})
      namespace = options.fetch(:namespace, ApiPlayground.configuration.default_namespace)
      source = options.fetch(:source, ApiPlayground.configuration.default_source)

      namespace namespace do
        scope source do
          get ':model_name', to: "#{source}#discover"
          get ':model_name/:id', to: "#{source}#discover"
          post ':model_name', to: "#{source}#create"
          patch ':model_name/:id', to: "#{source}#update"
          delete ':model_name/:id', to: "#{source}#destroy"
        end
      end
    end
  end
end 