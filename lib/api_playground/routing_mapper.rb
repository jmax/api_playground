module ApiPlayground
  module RoutingMapper
    # Defines a set of RESTful API routes for the playground functionality
    #
    # @example Basic usage within existing namespace
    #   namespace :api do
    #     api_playground_routes controller: 'playground'
    #   end
    #   # => Creates routes under /api/playground/...
    #
    # @example With explicit namespace (creates its own namespace)
    #   api_playground_routes namespace: :v1, controller: 'playground'
    #   # => Creates routes under /v1/playground/...
    #
    # @example Custom source controller within namespace
    #   namespace :api do
    #     api_playground_routes source: :explorer
    #   end
    #   # => Creates routes under /api/explorer/... using ExplorerController
    #
    # @param [Hash] options The configuration options
    # @option options [Symbol] :namespace The namespace under which the routes will be created (optional)
    # @option options [Symbol] :source The base name for the controller and URL path
    # @option options [Symbol] :controller Alias for :source (for backwards compatibility)
    def api_playground_routes(options = {})
      source = options.fetch(:controller, options.fetch(:source, ApiPlayground.configuration.default_source))
      
      # Define the route block
      route_block = proc do
        scope source do
          # Documentation route - must come first and be explicit
          get 'docs', to: "#{source}#docs"
          
          # Model routes
          get ':model_name', to: "#{source}#discover"
          get ':model_name/:id', to: "#{source}#discover"
          post ':model_name', to: "#{source}#create"
          patch ':model_name/:id', to: "#{source}#update"
          delete ':model_name/:id', to: "#{source}#destroy"
        end
      end
      
      # If namespace is explicitly provided, wrap in namespace
      if options.key?(:namespace)
        namespace_name = options[:namespace]
        namespace namespace_name, &route_block
      else
        # Otherwise, just apply the routes directly (assumes we're already in desired namespace)
        route_block.call
      end
    end
  end
end 