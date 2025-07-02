# frozen_string_literal: true

# ApiPlayground::Documentation provides OpenAPI v3 specification generation for playground APIs.
# When included in a controller that also includes ApiPlayground, it adds a `/docs` endpoint
# that serves comprehensive API documentation in OpenAPI v3 format.
#
# Features:
# - Automatic OpenAPI v3.0.3 specification generation
# - Schema definitions based on playground configurations
# - Path definitions for all configured CRUD operations
# - Request/response examples
# - Error response schemas
# - Security definitions for API key authentication
#
# @example Basic usage in a controller
#   class Api::PlaygroundController < ApplicationController
#     include ApiPlayground
#     include ApiPlayground::Documentation
#
#     playground_for :recipe,
#                   attributes: [:title, :body],
#                   requests: { create: { fields: [:title, :body] }, update: { fields: [:title] }, delete: true }
#   end
#
# @example Accessing the documentation
#   GET /api/playground/docs
#   # Returns OpenAPI v3 JSON specification
#
# @example Integration with API protection
#   class Api::PlaygroundController < ApplicationController
#     include ApiPlayground
#     include ApiPlayground::Documentation
#     include ApiPlayground::ApiKeyProtection
#     protected_playground!
#   end
#
# The documentation endpoint respects the same protection settings as the API endpoints.
module ApiPlayground
  module Documentation
    extend ActiveSupport::Concern

    # Renders the OpenAPI v3 specification for the configured playground API.
    # The specification includes all configured models, their schemas, operations, and examples.
    #
    # @example Request
    #   GET /api/playground/docs
    #   Accept: application/json
    #
    # @example Response
    #   {
    #     "openapi": "3.0.3",
    #     "info": {
    #       "title": "API Playground",
    #       "version": "1.0.0",
    #       "description": "Interactive API documentation for playground endpoints"
    #     },
    #     "paths": { ... },
    #     "components": { ... }
    #   }
    #
    # @note This method is automatically called by Rails routing
    def docs
      render json: generate_openapi_spec, status: :ok
    end

    private

    # Generates the complete OpenAPI v3 specification
    #
    # @return [Hash] Complete OpenAPI v3 specification
    #
    # @api private
    def generate_openapi_spec
      {
        openapi: '3.0.3',
        info: generate_info_section,
        servers: generate_servers_section,
        paths: generate_paths_section,
        components: generate_components_section
      }
    end

    # Generates the OpenAPI info section
    #
    # @return [Hash] Info section of the OpenAPI spec
    #
    # @api private
    def generate_info_section
      {
        title: 'API Playground',
        version: '1.0.0',
        description: 'Interactive API documentation for playground endpoints'
      }
    end

    # Generates the OpenAPI servers section
    #
    # @return [Array<Hash>] Servers section of the OpenAPI spec
    #
    # @api private
    def generate_servers_section
      [{ url: request.base_url, description: 'Current server' }]
    end

    # Generates the OpenAPI paths section with all configured model operations
    #
    # @return [Hash] Paths section of the OpenAPI spec
    #
    # @api private
    def generate_paths_section
      paths = {}
      base_path = extract_base_path

      self.class.playground_configurations.each do |model_name, config|
        model_paths = generate_model_paths(model_name, config, base_path)
        paths.merge!(model_paths)
      end

      paths
    end

    # Generates paths for a specific model
    #
    # @param model_name [String] Name of the model
    # @param config [Hash] Configuration for the model
    # @param base_path [String] Base path for the API
    # @return [Hash] Paths for the model
    #
    # @api private
    def generate_model_paths(model_name, config, base_path)
      paths = {}
      model_plural = model_name.pluralize
      collection_path = "#{base_path}/#{model_plural}"
      resource_path = "#{base_path}/#{model_plural}/{id}"

      paths[collection_path] = { get: generate_list_operation(model_name, config) }
      paths[collection_path][:post] = generate_create_operation(model_name, config) if config.dig(:requests, :create)

      paths[resource_path] = { get: generate_show_operation(model_name, config) }
      paths[resource_path][:patch] = generate_update_operation(model_name, config) if config.dig(:requests, :update)
      paths[resource_path][:delete] = generate_delete_operation(model_name, config) if config.dig(:requests, :delete)

      paths
    end

    # Generates the list/index operation specification
    #
    # @param model_name [String] Name of the model
    # @param config [Hash] Configuration for the model
    # @return [Hash] OpenAPI operation specification
    #
    # @api private
    def generate_list_operation(model_name, config)
      {
        summary: "List #{model_name.pluralize.humanize}",
        description: "Retrieve a paginated list of #{model_name.pluralize.humanize.downcase}",
        tags: [model_name.humanize],
        responses: {
          '200' => { description: 'Successful response' },
          '401' => { description: 'Unauthorized' },
          '404' => { description: 'Not found' }
        }
      }
    end

    # Generates the show/detail operation specification
    #
    # @param model_name [String] Name of the model
    # @param config [Hash] Configuration for the model
    # @return [Hash] OpenAPI operation specification
    #
    # @api private
    def generate_show_operation(model_name, config)
      {
        summary: "Get #{model_name.humanize}",
        description: "Retrieve a specific #{model_name.humanize.downcase} by ID",
        tags: [model_name.humanize],
        parameters: [{
          name: 'id', in: 'path', required: true,
          description: "ID of the #{model_name.humanize.downcase}",
          schema: { type: 'integer' }
        }],
        responses: {
          '200' => { description: 'Successful response' },
          '401' => { description: 'Unauthorized' },
          '404' => { description: 'Not found' }
        }
      }
    end

    # Generates the create operation specification
    #
    # @param model_name [String] Name of the model
    # @param config [Hash] Configuration for the model
    # @return [Hash] OpenAPI operation specification
    #
    # @api private
    def generate_create_operation(model_name, config)
      {
        summary: "Create #{model_name.humanize}",
        description: "Create a new #{model_name.humanize.downcase}",
        tags: [model_name.humanize],
        requestBody: { required: true },
        responses: {
          '201' => { description: 'Created successfully' },
          '400' => { description: 'Bad request' },
          '422' => { description: 'Validation error' }
        }
      }
    end

    # Generates the update operation specification
    #
    # @param model_name [String] Name of the model
    # @param config [Hash] Configuration for the model
    # @return [Hash] OpenAPI operation specification
    #
    # @api private
    def generate_update_operation(model_name, config)
      {
        summary: "Update #{model_name.humanize}",
        description: "Update an existing #{model_name.humanize.downcase}",
        tags: [model_name.humanize],
        parameters: [{
          name: 'id', in: 'path', required: true,
          description: "ID of the #{model_name.humanize.downcase}",
          schema: { type: 'integer' }
        }],
        requestBody: { required: true },
        responses: {
          '200' => { description: 'Updated successfully' },
          '400' => { description: 'Bad request' },
          '404' => { description: 'Not found' },
          '422' => { description: 'Validation error' }
        }
      }
    end

    # Generates the delete operation specification
    #
    # @param model_name [String] Name of the model
    # @param config [Hash] Configuration for the model
    # @return [Hash] OpenAPI operation specification
    #
    # @api private
    def generate_delete_operation(model_name, config)
      {
        summary: "Delete #{model_name.humanize}",
        description: "Delete an existing #{model_name.humanize.downcase}",
        tags: [model_name.humanize],
        parameters: [{
          name: 'id', in: 'path', required: true,
          description: "ID of the #{model_name.humanize.downcase}",
          schema: { type: 'integer' }
        }],
        responses: {
          '204' => { description: 'Deleted successfully' },
          '401' => { description: 'Unauthorized' },
          '404' => { description: 'Not found' }
        }
      }
    end

    # Generates the OpenAPI components section
    #
    # @return [Hash] Components section of the OpenAPI spec
    #
    # @api private
    def generate_components_section
      {
        schemas: generate_schemas_section,
        responses: generate_responses_section,
        securitySchemes: generate_security_schemes_section
      }
    end

    # Generates schemas for all configured models
    #
    # @return [Hash] Schema definitions
    #
    # @api private
    def generate_schemas_section
      schemas = {}
      
      self.class.playground_configurations.each do |model_name, config|
        schemas.merge!(generate_model_schemas(model_name, config))
      end
      
      schemas.merge!(generate_error_schemas)
    end

    # Generates schemas for a specific model
    #
    # @param model_name [String] Name of the model
    # @param config [Hash] Configuration for the model
    # @return [Hash] Schema definitions for the model
    #
    # @api private
    def generate_model_schemas(model_name, config)
      model_class_name = model_name.classify
      {
        "#{model_class_name}Resource" => generate_resource_schema(model_name, config),
        "#{model_class_name}Response" => {
          type: 'object',
          properties: {
            data: { '$ref' => "#/components/schemas/#{model_class_name}Resource" }
          }
        }
      }
    end

    # Generates the resource schema based on configured attributes
    #
    # @param model_name [String] Name of the model
    # @param config [Hash] Configuration for the model
    # @return [Hash] Resource schema definition
    #
    # @api private
    def generate_resource_schema(model_name, config)
      properties = {
        id: { type: 'string' },
        type: { type: 'string', enum: [model_name.pluralize] },
        attributes: generate_attributes_schema(config[:attributes])
      }

      { type: 'object', properties: properties }
    end

    # Generates the attributes schema based on configuration
    #
    # @param attributes_config [Hash] Attributes configuration
    # @return [Hash] Attributes schema definition
    #
    # @api private
    def generate_attributes_schema(attributes_config)
      properties = {}
      
      attributes_config[:ungrouped]&.each do |attr|
        properties[attr] = { type: 'string' }
      end

      { type: 'object', properties: properties }
    end

    # Generates common error schemas
    #
    # @return [Hash] Error schema definitions
    #
    # @api private
    def generate_error_schemas
      {
        'ErrorObject' => {
          type: 'object',
          properties: {
            status: { type: 'string' },
            title: { type: 'string' },
            detail: { type: 'string' }
          }
        }
      }
    end

    # Generates common response definitions
    #
    # @return [Hash] Response definitions
    #
    # @api private
    def generate_responses_section
      {
        'BadRequest' => { description: 'Bad Request' },
        'Unauthorized' => { description: 'Unauthorized' },
        'NotFound' => { description: 'Resource not found' }
      }
    end

    # Generates security schemes section
    #
    # @return [Hash] Security schemes definitions
    #
    # @api private
    def generate_security_schemes_section
      {
        'ApiKeyAuth' => {
          type: 'apiKey',
          in: 'header',
          name: 'X-API-Key'
        }
      }
    end

    # Extracts the base path from the current request
    #
    # @return [String] Base path for the API
    #
    # @api private
    def extract_base_path
      request.path.sub(%r{/docs$}, '')
    end
  end
end 