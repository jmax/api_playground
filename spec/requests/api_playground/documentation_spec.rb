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
      expect(recipe_list['description']).to eq('Retrieve a paginated list of recipes')
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