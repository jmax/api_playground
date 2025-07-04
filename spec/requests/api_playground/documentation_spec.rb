# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ApiPlayground::Documentation', type: :request do
  # Create a test controller that includes both concerns
  let(:controller_class) do
    Class.new(ApplicationController) do
      include ApiPlayground
      include ApiPlayground::Documentation

      playground_for :recipe,
                    attributes: [:title, :body, :description],
                    requests: {
                      create: { fields: [:title, :body] },
                      update: { fields: [:title, :body] },
                      delete: true
                    },
                    pagination: { enabled: true, page_size: 20 },
                    filters: [
                      { field: 'title', type: :exact },
                      { field: 'body', type: :partial }
                    ]

      playground_for :user,
                    attributes: [:name, :email],
                    requests: {
                      create: false,
                      update: { fields: [:name] },
                      delete: false
                    }
    end
  end

  before do
    # Create a temporary controller for testing
    stub_const('Api::TestPlaygroundController', controller_class)
    
    # Create temporary routes
    Rails.application.routes.draw do
      namespace :api do
        scope :test_playground do
          get 'docs', to: 'test_playground#docs'
          get ':model_name', to: 'test_playground#discover'
          get ':model_name/:id', to: 'test_playground#discover'
          post ':model_name', to: 'test_playground#create'
          patch ':model_name/:id', to: 'test_playground#update'
          delete ':model_name/:id', to: 'test_playground#destroy'
        end
      end
    end
  end

  after do
    # Reload original routes
    Rails.application.reload_routes!
  end

  describe 'GET /api/test_playground/docs' do
    it 'returns a valid OpenAPI v3 specification' do
      get '/api/test_playground/docs'

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')

      spec = JSON.parse(response.body)

      # Verify OpenAPI version
      expect(spec['openapi']).to eq('3.0.3')

      # Verify info section
      expect(spec['info']).to include(
        'title' => 'API Playground',
        'version' => '1.0.0',
        'description' => 'Interactive API documentation for playground endpoints'
      )

      # Verify servers section
      expect(spec['servers']).to be_an(Array)
      expect(spec['servers'].first).to include('url' => 'http://www.example.com')

      # Verify paths section exists
      expect(spec['paths']).to be_a(Hash)

      # Verify components section exists
      expect(spec['components']).to be_a(Hash)
      expect(spec['components']).to include('schemas', 'responses', 'securitySchemes')
    end

    it 'includes paths for configured models' do
      get '/api/test_playground/docs'
      spec = JSON.parse(response.body)

      paths = spec['paths']

      # Recipe endpoints
      expect(paths).to have_key('/api/test_playground/recipes')
      expect(paths).to have_key('/api/test_playground/recipes/{id}')

      # User endpoints
      expect(paths).to have_key('/api/test_playground/users')
      expect(paths).to have_key('/api/test_playground/users/{id}')
    end

    it 'includes correct operations for each model based on configuration' do
      get '/api/test_playground/docs'
      spec = JSON.parse(response.body)

      paths = spec['paths']

      # Recipe endpoints (all operations enabled)
      recipe_collection = paths['/api/test_playground/recipes']
      expect(recipe_collection).to have_key('get')  # list
      expect(recipe_collection).to have_key('post') # create

      recipe_resource = paths['/api/test_playground/recipes/{id}']
      expect(recipe_resource).to have_key('get')    # show
      expect(recipe_resource).to have_key('patch')  # update
      expect(recipe_resource).to have_key('delete') # delete

      # User endpoints (limited operations)
      user_collection = paths['/api/test_playground/users']
      expect(user_collection).to have_key('get')     # list
      expect(user_collection).not_to have_key('post') # create disabled

      user_resource = paths['/api/test_playground/users/{id}']
      expect(user_resource).to have_key('get')     # show
      expect(user_resource).to have_key('patch')   # update
      expect(user_resource).not_to have_key('delete') # delete disabled
    end

    it 'includes schemas for configured models' do
      get '/api/test_playground/docs'
      spec = JSON.parse(response.body)

      schemas = spec['components']['schemas']

      # Recipe schemas
      expect(schemas).to have_key('RecipeResource')
      expect(schemas).to have_key('RecipeResponse')

      # User schemas
      expect(schemas).to have_key('UserResource')
      expect(schemas).to have_key('UserResponse')

      # Error schemas
      expect(schemas).to have_key('ErrorObject')
    end

    it 'includes proper operation summaries and descriptions' do
      get '/api/test_playground/docs'
      spec = JSON.parse(response.body)

      # Check a sample operation
      recipe_list = spec['paths']['/api/test_playground/recipes']['get']
      expect(recipe_list['summary']).to eq('List Recipes')
      expect(recipe_list['description']).to include('Retrieve a list of recipes with pagination and filtering')
      expect(recipe_list['description']).to include('Available filters: title, body')
      expect(recipe_list['tags']).to eq(['Recipe'])
    end

    it 'includes proper response definitions' do
      get '/api/test_playground/docs'
      spec = JSON.parse(response.body)

      responses = spec['components']['responses']

      expect(responses).to have_key('BadRequest')
      expect(responses).to have_key('Unauthorized')
      expect(responses).to have_key('NotFound')

      expect(responses['BadRequest']).to include('description' => 'Bad Request')
      expect(responses['Unauthorized']).to include('description' => 'Unauthorized')
      expect(responses['NotFound']).to include('description' => 'Resource not found')
    end

    it 'includes security schemes' do
      get '/api/test_playground/docs'
      spec = JSON.parse(response.body)

      security_schemes = spec['components']['securitySchemes']

      expect(security_schemes).to have_key('ApiKeyAuth')
      expect(security_schemes['ApiKeyAuth']).to include(
        'type' => 'apiKey',
        'in' => 'header',
        'name' => 'X-API-Key'
      )
    end

    it 'generates resource schemas with correct attribute types' do
      get '/api/test_playground/docs'
      spec = JSON.parse(response.body)

      recipe_resource = spec['components']['schemas']['RecipeResource']
      
      expect(recipe_resource['type']).to eq('object')
      expect(recipe_resource['properties']).to have_key('id')
      expect(recipe_resource['properties']).to have_key('type')
      expect(recipe_resource['properties']).to have_key('attributes')
      
      # Check type enum
      expect(recipe_resource['properties']['type']['enum']).to eq(['recipes'])
      
      # Check attributes structure
      attributes = recipe_resource['properties']['attributes']
      expect(attributes['type']).to eq('object')
      expect(attributes['properties']).to have_key('title')
      expect(attributes['properties']).to have_key('body')
      expect(attributes['properties']).to have_key('description')
    end

    it 'includes filter parameters in list operations' do
      get '/api/test_playground/docs'
      spec = JSON.parse(response.body)

      # Check recipe list operation parameters
      recipe_list = spec['paths']['/api/test_playground/recipes']['get']
      expect(recipe_list).to have_key('parameters')
      
      parameters = recipe_list['parameters']
      parameter_names = parameters.map { |p| p['name'] }

      # Should include pagination parameters
      expect(parameter_names).to include('page[number]')
      expect(parameter_names).to include('page[size]')

      # Should include filter parameters
      expect(parameter_names).to include('filters[title]')
      expect(parameter_names).to include('filters[body]')

      # Check specific filter parameter details
      title_filter = parameters.find { |p| p['name'] == 'filters[title]' }
      expect(title_filter['description']).to include('exact match')
      expect(title_filter['required']).to be false
      expect(title_filter['schema']['type']).to eq('string')

      body_filter = parameters.find { |p| p['name'] == 'filters[body]' }
      expect(body_filter['description']).to include('partial match')

      # Check pagination parameter details
      page_number = parameters.find { |p| p['name'] == 'page[number]' }
      expect(page_number['schema']['type']).to eq('integer')
      expect(page_number['schema']['minimum']).to eq(1)
      expect(page_number['schema']['default']).to eq(1)

      page_size = parameters.find { |p| p['name'] == 'page[size]' }
      expect(page_size['schema']['default']).to eq(20) # From test configuration
      expect(page_size['schema']['maximum']).to eq(50)
    end

    it 'adapts filter parameters to field types' do
      get '/api/test_playground/docs'
      spec = JSON.parse(response.body)

      # Check user list operation (which has different field types)
      user_list = spec['paths']['/api/test_playground/users']['get']
      parameters = user_list['parameters']

      # Should only have pagination (no filters configured for users in test)
      parameter_names = parameters.map { |p| p['name'] }
      expect(parameter_names).to include('page[number]')
      expect(parameter_names).to include('page[size]')
      expect(parameter_names).not_to include('filters[name]') # No filters configured for users
    end

    it "includes request body schema for create operations" do
      get "/api/test_playground/docs"
      
      json = JSON.parse(response.body)
      create_operation = json.dig('paths', '/api/test_playground/recipes', 'post')
      
      expect(create_operation).to include('requestBody')
      request_body = create_operation['requestBody']
      
      expect(request_body).to include('required' => true)
      expect(request_body).to include('content')
      
      json_content = request_body.dig('content', 'application/json')
      expect(json_content).to include('schema', 'example')
      
      # Check schema structure
      schema = json_content['schema']
      expect(schema).to include('type' => 'object')
      expect(schema['properties']).to include('data')
      
      data_schema = schema.dig('properties', 'data')
      expect(data_schema['properties']).to include('type', 'attributes')
      
      # Check attributes schema
      attributes_schema = data_schema.dig('properties', 'attributes')
      expect(attributes_schema).to include('properties')
      expect(attributes_schema['properties']).to include('title', 'body')
      
      # Check example structure
      example = json_content['example']
      expect(example).to include('data')
      expect(example['data']).to include('type' => 'recipes')
      expect(example['data']).to include('attributes')
      expect(example['data']['attributes']).to include('title', 'body')
    end

    it "includes request body schema for update operations" do
      get "/api/test_playground/docs"
      
      json = JSON.parse(response.body)
      update_operation = json.dig('paths', '/api/test_playground/recipes/{id}', 'patch')
      
      expect(update_operation).to include('requestBody')
      request_body = update_operation['requestBody']
      
      expect(request_body).to include('required' => true)
      json_content = request_body.dig('content', 'application/json')
      
      # Check example structure
      example = json_content['example']
      expect(example['data']['attributes']).to include('title', 'body')
    end

    it "generates appropriate example values for different field types" do
      # Add a more complex configuration
      allow(Api::TestPlaygroundController).to receive(:playground_configurations).and_return({
        'user' => {
          attributes: { ungrouped: [:name, :email, :age, :is_active, :created_at, :profile_url, :bio] },
          requests: {
            create: { fields: [:name, :email, :age, :is_active, :profile_url, :bio] }
          }
        }
      })
      
      get "/api/test_playground/docs"
      
      json = JSON.parse(response.body)
      create_operation = json.dig('paths', '/api/test_playground/users', 'post')
      example = create_operation.dig('requestBody', 'content', 'application/json', 'example')
      
      attributes = example.dig('data', 'attributes')
      expect(attributes['name']).to be_a(String)
      expect(attributes['email']).to match(/@/)
      expect(attributes['age']).to be_a(Integer) if attributes.key?('age')
      expect(attributes['is_active']).to be_in([true, false])
      expect(attributes['profile_url']).to include('http')
      expect(attributes['bio']).to be_a(String)
    end

    it "generates intelligent schema types for different fields" do
      # Configure controller with varied field types
      allow(Api::TestPlaygroundController).to receive(:playground_configurations).and_return({
        'product' => {
          attributes: { ungrouped: [:name, :price, :category_id, :is_featured, :created_at, :website_url] },
          requests: {
            create: { fields: [:name, :price, :category_id, :is_featured, :website_url] }
          }
        }
      })
      
      get "/api/test_playground/docs"
      
      json = JSON.parse(response.body)
      create_operation = json.dig('paths', '/api/test_playground/products', 'post')
      attributes_schema = create_operation.dig('requestBody', 'content', 'application/json', 'schema', 'properties', 'data', 'properties', 'attributes', 'properties')
      
      expect(attributes_schema['name']['type']).to eq('string')
      expect(attributes_schema['price']['type']).to eq('number')
      expect(attributes_schema['price']['format']).to eq('float')
      expect(attributes_schema['category_id']['type']).to eq('integer')
      expect(attributes_schema['is_featured']['type']).to eq('boolean')
      expect(attributes_schema['website_url']['type']).to eq('string')
      expect(attributes_schema['website_url']['format']).to eq('uri')
    end

    it "marks certain fields as required in request body" do
      get "/api/test_playground/docs"
      
      json = JSON.parse(response.body)
      create_operation = json.dig('paths', '/api/test_playground/recipes', 'post')
      attributes_schema = create_operation.dig('requestBody', 'content', 'application/json', 'schema', 'properties', 'data', 'properties', 'attributes')
      
      # Title should be marked as required since it matches the pattern
      expect(attributes_schema['required']).to include('title')
    end

    it "handles empty request fields gracefully" do
      # Configure controller with no create fields
      allow(Api::TestPlaygroundController).to receive(:playground_configurations).and_return({
        'readonly_model' => {
          attributes: { ungrouped: [:name, :description] },
          requests: {
            create: { fields: [] }
          }
        }
      })
      
      get "/api/test_playground/docs"
      
      json = JSON.parse(response.body)
      create_operation = json.dig('paths', '/api/test_playground/readonly_models', 'post')
      
      # Should have basic required true but no detailed schema
      expect(create_operation['requestBody']).to eq({ 'required' => true })
    end
  end

  describe 'error handling' do
    it 'handles missing playground configurations gracefully' do
      # Create a controller without any playground configurations
      empty_controller = Class.new(ApplicationController) do
        include ApiPlayground
        include ApiPlayground::Documentation
      end

      stub_const('Api::EmptyTestController', empty_controller)

      Rails.application.routes.draw do
        namespace :api do
          get 'empty_test/docs', to: 'empty_test#docs'
        end
      end

      get '/api/empty_test/docs'

      expect(response).to have_http_status(:ok)
      spec = JSON.parse(response.body)
      
      expect(spec['paths']).to be_empty
      expect(spec['components']['schemas']).to have_key('ErrorObject') # Only common schemas
    end
  end
end 