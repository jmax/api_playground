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
      operation = {
        summary: "List #{model_name.pluralize.humanize}",
        description: generate_list_description(model_name, config),
        tags: [model_name.humanize],
        responses: {
          '200' => { description: 'Successful response' },
          '401' => { description: 'Unauthorized' },
          '404' => { description: 'Not found' }
        }
      }

      # Add parameters for pagination and filters
      parameters = generate_list_parameters(config)
      operation[:parameters] = parameters if parameters.any?

      operation
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
        requestBody: generate_request_body(model_name, config, :create),
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
        requestBody: generate_request_body(model_name, config, :update),
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

    # Generates request body specification for create/update operations
    #
    # @param model_name [String] Name of the model
    # @param config [Hash] Configuration for the model
    # @param operation [Symbol] The operation type (:create or :update)
    # @return [Hash] Request body specification
    #
    # @api private
    def generate_request_body(model_name, config, operation)
      allowed_fields = config.dig(:requests, operation, :fields) || []
      
      return { required: true } if allowed_fields.empty?

      {
        required: true,
        content: {
          'application/json' => {
            schema: {
              type: 'object',
              required: ['data'],
              properties: {
                data: {
                  type: 'object',
                  required: ['type', 'attributes'],
                  properties: {
                    type: { 
                      type: 'string', 
                      enum: [model_name.pluralize],
                      example: model_name.pluralize
                    },
                    attributes: {
                      type: 'object',
                      properties: generate_request_attributes_schema(allowed_fields),
                      required: extract_required_fields(allowed_fields)
                    }
                  }
                }
              }
            },
            example: generate_request_example(model_name, allowed_fields)
          }
        }
      }
    end

    # Generates schema for request attributes
    #
    # @param allowed_fields [Array] List of allowed field names
    # @return [Hash] Attributes schema
    #
    # @api private
    def generate_request_attributes_schema(allowed_fields)
      properties = {}
      
      allowed_fields.each do |field|
        properties[field] = generate_attribute_schema(field)
      end

      properties
    end

    # Generates example request body for create/update operations
    #
    # @param model_name [String] Name of the model
    # @param allowed_fields [Array] List of allowed field names
    # @return [Hash] Complete example request body
    #
    # @api private
    def generate_request_example(model_name, allowed_fields)
      attributes_example = {}
      
      allowed_fields.each do |field|
        attributes_example[field] = generate_attribute_example_value(field)
      end

      {
        data: {
          type: model_name.pluralize,
          attributes: attributes_example
        }
      }
    end

    # Generates schema for a single attribute based on field name
    #
    # @param field_name [Symbol, String] Field name
    # @return [Hash] Schema definition
    #
    # @api private
    def generate_attribute_schema(field_name)
      field_str = field_name.to_s
      
      case field_str
      when /_id$/, 'id'
        { type: 'integer', description: 'Numeric identifier', example: generate_attribute_example_value(field_name) }
      when /_at$/, /_on$/, /^created/, /^updated/, 'timestamp'
        { type: 'string', format: 'date-time', description: 'ISO8601 timestamp', example: generate_attribute_example_value(field_name) }
      when 'email'
        { type: 'string', format: 'email', description: 'Email address', example: generate_attribute_example_value(field_name) }
      when /_count$/, 'count', 'quantity', 'number', 'age'
        { type: 'integer', description: 'Numeric value', example: generate_attribute_example_value(field_name) }
      when /^is_/, /^has_/, 'active', 'enabled', 'published'
        { type: 'boolean', description: 'Boolean flag', example: generate_attribute_example_value(field_name) }
      when 'price', 'cost', 'amount', /_price$/, /_cost$/
        { type: 'number', format: 'float', description: 'Monetary value', example: generate_attribute_example_value(field_name) }
      when 'url', 'website', /_url$/
        { type: 'string', format: 'uri', description: 'URL', example: generate_attribute_example_value(field_name) }
      when 'description', 'summary', 'bio', 'about', 'content'
        { type: 'string', description: 'Long text content', example: generate_attribute_example_value(field_name) }
      else
        { type: 'string', description: field_str.humanize, example: generate_attribute_example_value(field_name) }
      end
    end

    # Generates realistic example values for attributes
    #
    # @param field_name [Symbol, String] Field name
    # @return [String, Integer, Boolean, Float] Example value
    #
    # @api private
    def generate_attribute_example_value(field_name)
      field_str = field_name.to_s
      
      case field_str
      when /_id$/, 'id'
        case field_str
        when 'author_id', 'user_id'
          1
        when 'category_id'
          2
        when 'book_id'
          3
        else
          1
        end
      when /_at$/, /_on$/, /^created/, /^updated/, 'timestamp'
        Time.current.iso8601
      when 'email'
        'user@example.com'
      when /_count$/, 'count', 'quantity'
        10
      when 'number', 'age'
        case field_str
        when 'age'
          25
        when 'number'
          42
        else
          10
        end
      when /^is_/, /^has_/, 'active', 'enabled', 'published'
        true
      when 'price', 'cost', 'amount'
        29.99
      when /_price$/, /_cost$/
        case field_str
        when 'unit_price'
          9.99
        when 'total_cost'
          99.99
        else
          19.99
        end
      when 'url', 'website'
        'https://example.com'
      when /_url$/
        case field_str
        when 'image_url'
          'https://example.com/image.jpg'
        when 'profile_url'
          'https://example.com/profile'
        else
          'https://example.com'
        end
      when 'title'
        'Sample Title'
      when 'name'
        'Sample Name'
      when 'first_name'
        'John'
      when 'last_name'
        'Doe'
      when 'description'
        'This is a detailed description that provides comprehensive information about the item.'
      when 'summary'
        'A brief summary of the content.'
      when 'body'
        'This is the main content body with detailed information.'
      when 'bio', 'about'
        'A brief biography or about section.'
      when 'content'
        'Main content goes here with detailed information.'
      when 'tags'
        'tag1, tag2, tag3'
      when 'status'
        'active'
      when 'type'
        'standard'
      when 'category'
        'general'
      else
        case field_str.length
        when 1..10
          "Sample #{field_str.humanize}"
        else
          "Sample #{field_str.humanize.downcase} content"
        end
      end
    end

    # Extracts required fields from the allowed fields list
    # Heuristic: fields like 'title', 'name', 'email' are typically required
    #
    # @param fields [Array] List of allowed fields
    # @return [Array] List of required fields
    #
    # @api private
    def extract_required_fields(fields)
      required_patterns = %w[title name email]
      fields.select { |field| required_patterns.any? { |pattern| field.to_s.include?(pattern) } }.map(&:to_s)
    end

    # Generates dynamic description for list operation including filter information
    #
    # @param model_name [String] Name of the model
    # @param config [Hash] Configuration for the model
    # @return [String] Description text
    #
    # @api private
    def generate_list_description(model_name, config)
      base_description = "Retrieve a list of #{model_name.pluralize.humanize.downcase}"
      
      features = []
      features << "pagination" if config.dig(:pagination, :enabled)
      features << "filtering" if config[:filters]&.any?
      
      if features.any?
        base_description += " with #{features.join(' and ')}"
      end
      
      if config[:filters]&.any?
        filter_fields = config[:filters].map { |f| f[:field] }.join(', ')
        base_description += ". Available filters: #{filter_fields}"
      end
      
      base_description
    end

    # Generates parameters for list operations (pagination and filters)
    #
    # @param config [Hash] Configuration for the model
    # @return [Array<Hash>] Array of parameter specifications
    #
    # @api private
    def generate_list_parameters(config)
      parameters = []

      # Pagination parameters
      if config.dig(:pagination, :enabled)
        page_size = config.dig(:pagination, :page_size) || 15
        
        parameters << {
          name: 'page[number]',
          in: 'query',
          description: 'Page number for pagination (starts from 1)',
          required: false,
          schema: { 
            type: 'integer', 
            minimum: 1, 
            default: 1,
            example: 1
          }
        }
        
        parameters << {
          name: 'page[size]',
          in: 'query',
          description: "Number of items per page (maximum: 50)",
          required: false,
          schema: { 
            type: 'integer', 
            minimum: 1, 
            maximum: 50, 
            default: page_size,
            example: page_size
          }
        }
      end

      # Filter parameters
      config[:filters]&.each do |filter|
        filter_type_description = case filter[:type]
                                 when :exact
                                   "exact match"
                                 when :partial
                                   "partial match (case-insensitive search)"
                                 else
                                   "filter"
                                 end

        field_name = filter[:field]
        humanized_field = field_name.humanize.downcase

        parameters << {
          name: "filters[#{field_name}]",
          in: 'query',
          description: "Filter by #{humanized_field} using #{filter_type_description}",
          required: false,
          schema: generate_filter_schema(filter),
          example: generate_filter_example(filter)
        }
      end

      parameters
    end

    # Generates schema for a filter parameter based on field name and type
    #
    # @param filter [Hash] Filter configuration
    # @return [Hash] Schema definition
    #
    # @api private
    def generate_filter_schema(filter)
      field_name = filter[:field].to_s
      
      # Infer schema type based on field name patterns
      case field_name
      when /_id$/, 'id'
        { type: 'integer', description: 'Numeric identifier' }
      when /_at$/, /_on$/, /^created/, /^updated/, 'timestamp'
        { type: 'string', format: 'date-time', description: 'ISO8601 timestamp' }
      when 'email'
        { type: 'string', format: 'email', description: 'Email address' }
      when /_count$/, 'count', 'quantity', 'number'
        { type: 'integer', description: 'Numeric value' }
      when /^is_/, /^has_/, 'active', 'enabled', 'published'
        { type: 'boolean', description: 'Boolean value' }
      else
        { type: 'string', description: 'Text value' }
      end
    end

    # Generates example value for a filter parameter
    #
    # @param filter [Hash] Filter configuration
    # @return [String, Integer, Boolean] Example value
    #
    # @api private
    def generate_filter_example(filter)
      field_name = filter[:field].to_s
      filter_type = filter[:type]
      
      case field_name
      when /_id$/, 'id'
        1
      when 'title'
        filter_type == :partial ? 'Recipe' : 'Spaghetti Carbonara'
      when 'name'
        filter_type == :partial ? 'John' : 'John Doe'
      when 'email'
        'user@example.com'
      when 'status'
        'published'
      when /^is_/, /^has_/, 'active', 'enabled', 'published'
        true
      when /_count$/, 'count', 'quantity'
        10
      else
        filter_type == :partial ? 'search term' : 'exact value'
      end
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