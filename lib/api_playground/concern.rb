# frozen_string_literal: true

# ApiPlayground provides a flexible way to expose model data through a JSONAPI-compliant interface.
# It allows you to define which models and attributes should be exposed, including support for
# grouped attributes, relationships, and configurable create/update/delete operations.
#
# Features:
# - JSONAPI-compliant responses
# - Flexible attribute grouping
# - Relationship handling
# - Configurable create/update operations
# - Configurable delete operations
# - Automatic error handling
# - ISO8601 timestamp formatting
#
# @example Basic usage in a controller
#   class Api::PlaygroundController < ApplicationController
#     include ApiPlayground
#
#     playground_for :recipe,
#                   attributes: [:title, :summary],
#                   relationships: [:author]
#   end
#
# @example Full configuration with all options
#   playground_for :recipe,
#                 attributes: [
#                   :title,
#                   :summary,
#                   { timestamps: [:created_at, :updated_at] },
#                   { metrics: [:views_count, :likes_count] }
#                 ],
#                 relationships: [:author, :categories],
#                 requests: {
#                   create: { fields: [:title, :summary, :author_id] },
#                   update: { fields: [:title, :summary] },
#                   delete: true
#                 }
#
# @example Response format for a single resource
#   {
#     "data": {
#       "id": "1",
#       "type": "recipes",
#       "attributes": {
#         "title": "Spaghetti Carbonara",
#         "summary": "Classic Italian pasta dish",
#         "timestamps": {
#           "created_at": "2024-03-21T14:30:00Z",
#           "updated_at": "2024-03-21T14:30:00Z"
#         }
#       },
#       "relationships": {
#         "author": {
#           "data": { "id": "1", "type": "author" }
#         }
#       }
#     },
#     "meta": {
#       "available_attributes": {...},
#       "available_models": [...]
#     }
#   }
#
# @example Error response format
#   {
#     "errors": [{
#       "status": "422",
#       "title": "Validation Error",
#       "detail": "Title can't be blank",
#       "source": { "pointer": "/data/attributes/title" }
#     }]
#   }
#
# Supported HTTP Methods:
# - GET /api/playground/:model_name - List resources
# - GET /api/playground/:model_name/:id - Show resource
# - POST /api/playground/:model_name - Create resource
# - PATCH /api/playground/:model_name/:id - Update resource
# - DELETE /api/playground/:model_name/:id - Delete resource
#
# Error Handling:
# - 400 Bad Request (missing parameters)
# - 404 Not Found (model/record not found)
# - 405 Method Not Allowed (unsupported operations)
# - 422 Unprocessable Entity (validation errors)
# - 204 No Content (successful deletion)
module ApiPlayground
    extend ActiveSupport::Concern
  
    included do
      class_attribute :playground_configurations, default: {}
      
      # Only skip authenticity token verification if the callback exists
      # (it doesn't exist in API-only controllers)
      if respond_to?(:skip_before_action) && 
         _process_action_callbacks.any? { |callback| callback.filter == :verify_authenticity_token }
        skip_before_action :verify_authenticity_token, only: [:create, :update, :destroy]
      end
    end
  
    class_methods do
      # Configures a model for the API playground.
      #
      # @param model_name [Symbol] The name of the model to expose
      # @param options [Hash] Configuration options for the model
      # @option options [Array<Symbol, Hash>] :attributes List of attributes to expose.
      #   Can include both direct attributes and grouped attributes in hashes
      # @option options [Array<Symbol>] :relationships List of relationships to include
      # @option options [Array<Hash>] :filters List of filterable fields with their match type
      #   Each filter hash should contain :field and :type keys, where type can be :exact or :partial
      # @option options [Hash] :pagination Pagination configuration
      #   :enabled (Boolean) Whether pagination is enabled (defaults to true)
      #   :page_size (Integer) Default page size (defaults to 15, max 50)
      #   :total_count (Boolean) Whether to include total count in response (defaults to true)
      #
      # @example Basic attributes
      #   playground_for :recipe, attributes: [:title, :body]
      #
      # @example With grouped attributes
      #   playground_for :recipe,
      #                 attributes: [
      #                   :title,
      #                   { timestamps: [:created_at, :updated_at] }
      #                 ]
      #
      # @example With relationships
      #   playground_for :recipe,
      #                 attributes: [:title],
      #                 relationships: [:author]
      #
      # @example With filters
      #   playground_for :recipe,
      #                 attributes: [:title],
      #                 filters: [
      #                   { field: 'title', type: :exact },
      #                   { field: 'summary', type: :partial }
      #                 ]
      #
      # @example With pagination configuration
      #   playground_for :recipe,
      #                 attributes: [:title],
      #                 pagination: {
      #                   enabled: true,
      #                   page_size: 30
      #                 }
      def playground_for(model_name, options = {})
        attributes = normalize_attributes(options[:attributes])
        requests = normalize_requests(options[:requests])
        filters = normalize_filters(options[:filters])
        pagination = normalize_pagination(options[:pagination])
        
        self.playground_configurations = playground_configurations.merge(
          model_name.to_s => {
            attributes: attributes,
            relationships: options[:relationships] || [],
            requests: requests,
            filters: filters,
            pagination: pagination
          }
        )
      end
  
      private
  
      # Normalizes the pagination configuration into a standard format.
      #
      # @param pagination [Hash, nil] Raw pagination configuration
      # @return [Hash] Normalized pagination configuration
      #
      # @api private
      def normalize_pagination(pagination)
        config = pagination || {}
        
        {
          enabled: config.fetch(:enabled, true),
          page_size: [[config.fetch(:page_size, 15), 1].max, 50].min,
          total_count: config.fetch(:total_count, true)
        }
      end
  
      # Normalizes the attributes configuration into a standard format.
      #
      # @param attributes [Array<Symbol, Hash>] Raw attributes configuration
      # @return [Hash] Normalized attributes with ungrouped and grouped fields
      #
      # @api private
      def normalize_attributes(attributes)
        return [] if attributes.nil?
  
        attributes.each_with_object({ ungrouped: [] }) do |attr, result|
          case attr
          when Hash
            attr.each do |group, fields|
              result[group] = Array(fields)
            end
          else
            result[:ungrouped] << attr
          end
        end
      end
  
      # Normalizes the requests configuration into a standard format.
      #
      # @param requests [Hash] Raw requests configuration
      # @return [Hash] Normalized requests configuration
      #
      # @api private
      def normalize_requests(requests)
        return {} if requests.nil?
  
        requests.each_with_object({}) do |(key, value), normalized|
          normalized[key.to_sym] = case value
                                  when true, false
                                    value
                                  else
                                    value.transform_keys(&:to_sym)
                                  end
        end
      end
  
      # Normalizes the filters configuration into a standard format.
      #
      # @param filters [Array<Hash>] Raw filters configuration
      # @return [Array<Hash>] Normalized filters with field and type
      #
      # @api private
      def normalize_filters(filters)
        return [] if filters.nil?
  
        filters.map do |filter|
          {
            field: filter[:field].to_s,
            type: filter[:type].to_sym
          }
        end
      end
    end
  
    # Handles the API request and returns the appropriate response.
    # This action supports both collection and individual resource requests.
    #
    # @note This method is automatically called by Rails routing
    #
    # @example Collection request
    #   GET /api/playground/recipes
    #
    # @example Individual resource request
    #   GET /api/playground/recipes/1
    def discover
      model_name = params[:model_name].to_s.singularize
      
      # Special case: if someone accesses 'docs' without including Documentation module
      if model_name == 'doc' && !respond_to?(:docs)
        return render json: {
          error: 'Documentation not available',
          message: 'To enable API documentation, include ApiPlayground::Documentation in your controller'
        }, status: :not_found
      end
      
      config = self.class.playground_configurations[model_name]

      return model_not_found unless config

      model_class = model_name.classify.constantize
      
      if params[:id].present?
        discover_resource(model_class, config)
      else
        discover_collection(model_class, config)
      end
    rescue NameError => e
      model_not_found
    rescue ActiveRecord::RecordNotFound => e
      record_not_found
    end
  
    # Creates a new resource with the provided attributes.
    # Requires the model to have create permission configured in requests options.
    # Returns 201 Created on success, or appropriate error status on failure.
    #
    # @example Request format
    #   POST /api/playground/recipes
    #   {
    #     "data": {
    #       "attributes": {
    #         "title": "New Recipe",
    #         "summary": "A delicious recipe"
    #       }
    #     }
    #   }
    #
    # @example Success response (201 Created)
    #   {
    #     "data": {
    #       "id": "1",
    #       "type": "recipes",
    #       "attributes": {
    #         "title": "New Recipe",
    #         "summary": "A delicious recipe"
    #       }
    #     }
    #   }
    #
    # @example Error response (422 Unprocessable Entity)
    #   {
    #     "errors": [{
    #       "status": "422",
    #       "title": "Validation Error",
    #       "detail": "Title can't be blank",
    #       "source": { "pointer": "/data/attributes/title" }
    #     }]
    #   }
    #
    # @note This method is automatically called by Rails routing
    def create
      model_name = params[:model_name].to_s.singularize
      config = self.class.playground_configurations[model_name]
  
      return model_not_found unless config
      return request_not_supported(:create) unless config.dig(:requests, :create)
  
      model_class = model_name.classify.constantize
      allowed_fields = config.dig(:requests, :create, :fields)
      
      permitted_params = params.require(:data)
                              .require(:attributes)
                              .permit(allowed_fields)
  
      resource = model_class.new(permitted_params)
  
      if resource.save
        render json: {
          data: serialize_resource(resource, config)
        }, status: :created
      else
        render json: {
          errors: serialize_errors(resource)
        }, status: :unprocessable_entity
      end
    rescue NameError => e
      model_not_found
    rescue ActionController::ParameterMissing => e
      parameter_missing(e)
    end
  
    # Updates an existing resource with the provided attributes.
    # Requires the model to have update permission configured in requests options.
    # Returns 200 OK on success, or appropriate error status on failure.
    #
    # @example Request format
    #   PATCH /api/playground/recipes/1
    #   {
    #     "data": {
    #       "attributes": {
    #         "title": "Updated Recipe Title",
    #         "summary": "An updated summary"
    #       }
    #     }
    #   }
    #
    # @example Success response (200 OK)
    #   {
    #     "data": {
    #       "id": "1",
    #       "type": "recipes",
    #       "attributes": {
    #         "title": "Updated Recipe Title",
    #         "summary": "An updated summary"
    #       }
    #     }
    #   }
    #
    # @example Error response (422 Unprocessable Entity)
    #   {
    #     "errors": [{
    #       "status": "422",
    #       "title": "Validation Error",
    #       "detail": "Title can't be blank",
    #       "source": { "pointer": "/data/attributes/title" }
    #     }]
    #   }
    #
    # @note This method is automatically called by Rails routing
    def update
      model_name = params[:model_name].to_s.singularize
      config = self.class.playground_configurations[model_name]
  
      return model_not_found unless config
      return request_not_supported(:update) unless config.dig(:requests, :update)
  
      model_class = model_name.classify.constantize
      allowed_fields = config.dig(:requests, :update, :fields)
      
      resource = model_class.find(params[:id])
      
      permitted_params = params.require(:data)
                              .require(:attributes)
                              .permit(allowed_fields)
  
      if resource.update(permitted_params)
        render json: {
          data: serialize_resource(resource, config)
        }, status: :ok
      else
        render json: {
          errors: serialize_errors(resource)
        }, status: :unprocessable_entity
      end
    rescue NameError => e
      model_not_found
    rescue ActiveRecord::RecordNotFound => e
      record_not_found
    rescue ActionController::ParameterMissing => e
      parameter_missing(e)
    end
  
    # Handles deletion of a resource.
    # Returns 204 No Content on success, or appropriate error status on failure.
    #
    # @example
    #   DELETE /api/playground/recipes/1
    #
    # @note This method is automatically called by Rails routing
    def destroy
      model_name = params[:model_name].to_s.singularize
      config = self.class.playground_configurations[model_name]
  
      return model_not_found unless config
      return request_not_supported(:delete) unless config.dig(:requests, :delete)
  
      model_class = model_name.classify.constantize
      resource = model_class.find(params[:id])
      
      if resource.destroy
        head :no_content
      else
        render json: {
          errors: [{
            status: '422',
            title: 'Deletion Error',
            detail: 'The resource could not be deleted',
            source: { pointer: "/data/#{model_name}/#{params[:id]}" }
          }]
        }, status: :unprocessable_entity
      end
    rescue NameError => e
      model_not_found
    rescue ActiveRecord::RecordNotFound => e
      record_not_found
    end
  
    private
  
    # Handles requests for individual resources.
    #
    # @param model_class [Class] The model class to query
    # @param config [Hash] The configuration for this model
    #
    # @api private
    def discover_resource(model_class, config)
      resource = if config[:relationships].present?
                  model_class.includes(*config[:relationships]).find(params[:id])
                else
                  model_class.find(params[:id])
                end
  
      render json: {
        data: serialize_resource(resource, config),
        meta: {
          available_attributes: config[:attributes],
          available_models: self.class.playground_configurations.keys
        }
      }
    end
  
    # Handles requests for collections of resources.
    #
    # @param model_class [Class] The model class to query
    # @param config [Hash] The configuration for this model
    #
    # @api private
    def discover_collection(model_class, config)
      scope = model_class
      scope = scope.includes(*config[:relationships]) if config[:relationships].present?
  
      # Apply filters if present in the request
      if params[:filters].present? && config[:filters].present?
        scope = apply_filters(scope, params[:filters], config[:filters])
      end
  
      # Calculate total count before pagination if enabled
      total_count = if config.dig(:pagination, :enabled) && config.dig(:pagination, :total_count)
        scope.count
      end
  
      # Apply pagination if enabled, otherwise get all records
      if config.dig(:pagination, :enabled)
        scope = paginate_scope(scope, config[:pagination], total_count)
      else
        scope = scope.all
      end
  
      resources = scope
  
      render json: {
        data: resources.map { |resource| serialize_resource(resource, config) },
        meta: build_meta_data(config, total_count)
      }
    end
  
    # Applies filters to the query scope based on request parameters and configuration
    #
    # @param scope [ActiveRecord::Relation] The initial query scope
    # @param filter_params [Hash] The filter parameters from the request
    # @param filter_config [Array<Hash>] The configured filters for the model
    # @return [ActiveRecord::Relation] The filtered scope
    #
    # @api private
    def apply_filters(scope, filter_params, filter_config)
      filter_params.each do |field, value|
        filter = filter_config.find { |f| f[:field] == field }
        next unless filter
  
        case filter[:type]
        when :exact
          scope = scope.where(field => value)
        when :partial
          scope = scope.where("LOWER(#{field}) LIKE ?", "%#{value.downcase}%")
        end
      end
      scope
    end
  
    # Paginates a scope based on request parameters and configuration
    #
    # @param scope [ActiveRecord::Relation] The scope to paginate
    # @param pagination_config [Hash] The pagination configuration
    # @param total_count [Integer, nil] The total number of records (nil if counting disabled)
    # @return [ActiveRecord::Relation] The paginated scope
    #
    # @api private
    def paginate_scope(scope, pagination_config, total_count)
      page = [params.dig(:page, :number).to_i, 1].max
      requested_size = params.dig(:page, :size)
      
      # If page size not specified in request, use configured size
      page_size = if requested_size.nil?
        pagination_config[:page_size]
      else
        [[requested_size.to_i, 1].max, 50].min
      end
      
      # Calculate offset and limit
      offset = (page - 1) * page_size
      
      scope.offset(offset).limit(page_size)
    end
  
    # Builds metadata for the response including pagination information
    #
    # @param config [Hash] The model configuration
    # @param total_count [Integer, nil] The total number of records (nil if counting disabled)
    # @return [Hash] The metadata hash
    #
    # @api private
    def build_meta_data(config, total_count)
      meta = {
        available_attributes: config[:attributes],
        available_filters: config[:filters],
        available_models: self.class.playground_configurations.keys
      }
  
      # Only include total_count if it was calculated
      meta[:total_count] = total_count if total_count
  
      if config.dig(:pagination, :enabled)
        page = [params.dig(:page, :number).to_i, 1].max
        requested_size = params.dig(:page, :size)
        
        # Use same logic as paginate_scope for consistency
        page_size = if requested_size.nil?
          config.dig(:pagination, :page_size)
        else
          [[requested_size.to_i, 1].max, 50].min
        end
  
        pagination_meta = {
          current_page: page,
          page_size: page_size
        }
  
        # Only include total_pages if we have total_count
        if total_count
          pagination_meta[:total_pages] = (total_count.to_f / page_size).ceil
        end
  
        meta[:pagination] = pagination_meta
      end
  
      meta
    end
  
    # Serializes a resource into a JSONAPI-compliant format.
    #
    # @param resource [ApplicationRecord] The resource to serialize
    # @param config [Hash] The configuration for this model
    # @return [Hash] The serialized resource
    #
    # @api private
    def serialize_resource(resource, config)
      response = {
        id: resource.id.to_s,
        type: resource.class.name.underscore.pluralize,
        attributes: serialize_attributes(resource, config[:attributes])
      }
  
      if config[:relationships].present?
        response[:relationships] = config[:relationships].each_with_object({}) { |rel, hash|
          related_resource = resource.send(rel)
          
          hash[rel] = if related_resource
            {
              data: if related_resource.respond_to?(:each)
                related_resource.map { |r| { id: r.id.to_s, type: rel.to_s } }
              else
                { id: related_resource.id.to_s, type: rel.to_s }
              end
            }
          else
            { data: nil }
          end
        }
      end
  
      response
    end
  
    # Serializes the attributes of a resource, handling both grouped and ungrouped attributes.
    #
    # @param resource [ApplicationRecord] The resource whose attributes to serialize
    # @param attributes_config [Hash] The attributes configuration
    # @return [Hash] The serialized attributes
    #
    # @api private
    def serialize_attributes(resource, attributes_config)
      result = {}
      errors = []
  
      attributes_config.each do |group, fields|
        next if fields.empty?
  
        if group == :ungrouped
          fields.each do |field|
            begin
              result[field] = format_attribute_value(resource.send(field))
            rescue NoMethodError => e
              errors << { attribute: field, message: "Method '#{field}' not found on #{resource.class.name}" }
            end
          end
        else
          group_values = {}
          has_valid_fields = false
  
          fields.each do |field|
            begin
              group_values[field] = format_attribute_value(resource.send(field))
              has_valid_fields = true
            rescue NoMethodError => e
              errors << { attribute: "#{group}.#{field}", message: "Method '#{field}' not found on #{resource.class.name}" }
            end
          end
  
          result[group] = group_values if has_valid_fields
        end
      end
  
      if errors.any?
        result[:_errors] = errors
      end
  
      result
    end
  
    # Formats attribute values, with special handling for timestamps.
    #
    # @param value [Object] The value to format
    # @return [Object] The formatted value
    #
    # @api private
    def format_attribute_value(value)
      case value
      when ActiveSupport::TimeWithZone, Time, DateTime, Date
        value.iso8601
      else
        value
      end
    end
  
    def serialize_errors(resource)
      resource.errors.map do |error|
        {
          status: '422',
          title: 'Validation Error',
          detail: error.full_message,
          source: { pointer: "/data/attributes/#{error.attribute}" }
        }
      end
    end
  
    # Renders a 404 error when the requested model is not found.
    #
    # @api private
    def model_not_found
      render json: { 
        errors: [{ 
          status: '404',
          title: 'Model not found',
          detail: "The requested model '#{params[:model_name]}' is not available in the playground",
          available_models: self.class.playground_configurations.keys
        }]
      }, status: :not_found
    end
  
    # Renders a 404 error when the requested record is not found.
    #
    # @api private
    def record_not_found
      render json: { 
        errors: [{ 
          status: '404',
          title: 'Record not found',
          detail: "Could not find #{params[:model_name].singularize} with id '#{params[:id]}'"
        }]
      }, status: :not_found
    end
  
    def request_not_supported(action)
      render json: {
        errors: [{
          status: '405',
          title: 'Request not supported',
          detail: "The model '#{params[:model_name]}' does not support #{action} operations"
        }]
      }, status: :method_not_allowed
    end
  
    def parameter_missing(error)
      render json: {
        errors: [{
          status: '400',
          title: 'Parameter missing',
          detail: "Required parameter missing: #{error.param}",
          source: { pointer: "/data/attributes" }
        }]
      }, status: :bad_request
    end
  end
  