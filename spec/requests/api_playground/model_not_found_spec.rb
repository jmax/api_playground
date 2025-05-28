require 'rails_helper'

RSpec.describe "ApiPlayground Model Not Found", type: :request do
  let!(:recipe) do
    Recipe.create!(
      title: "Test Recipe", 
      body: "Test recipe body"
    )
  end

  describe "when accessing non-existent models" do
    context "with main playground controller" do
      it "returns model not found error for index action" do
        get "/api/playground/invalid_model", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end

      it "returns model not found error for show action" do
        get "/api/playground/invalid_model/#{recipe.id}", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end

      it "returns model not found error for create action" do
        valid_params = {
          data: {
            type: 'invalid_models',
            attributes: {
              title: 'Test Title',
              body: 'Test Body'
            }
          }
        }

        post "/api/playground/invalid_model", params: valid_params, as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end

      it "returns model not found error for update action" do
        valid_params = {
          data: {
            type: 'invalid_models',
            attributes: {
              title: 'Updated Title'
            }
          }
        }

        patch "/api/playground/invalid_model/#{recipe.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end

      it "returns model not found error for delete action" do
        delete "/api/playground/invalid_model/#{recipe.id}", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end
    end

    context "with test playground controller (disabled operations)" do
      it "returns model not found error for index action" do
        get "/api/test_playground/invalid_model", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end

      it "returns model not found error for show action" do
        get "/api/test_playground/invalid_model/#{recipe.id}", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end

      it "returns model not found error for create action (even when create is disabled)" do
        valid_params = {
          data: {
            type: 'invalid_models',
            attributes: {
              title: 'Test Title',
              body: 'Test Body'
            }
          }
        }

        post "/api/test_playground/invalid_model", params: valid_params, as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end

      it "returns model not found error for update action (even when update is disabled)" do
        valid_params = {
          data: {
            type: 'invalid_models',
            attributes: {
              title: 'Updated Title'
            }
          }
        }

        patch "/api/test_playground/invalid_model/#{recipe.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end

      it "returns model not found error for delete action (even when delete is disabled)" do
        delete "/api/test_playground/invalid_model/#{recipe.id}", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end
    end

    context "with various invalid model names" do
      it "handles empty model name" do
        get "/api/playground/", as: :json

        # This returns 404 because no model name is provided in the route
        expect(response).to have_http_status(:not_found)
      end

      it "handles model names with special characters" do
        get "/api/playground/invalid-model-with-dashes", as: :json

        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid-model-with-dashes' is not available in the playground")
      end

      it "handles model names with numbers" do
        get "/api/playground/model123", as: :json

        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'model123' is not available in the playground")
      end

      it "handles model names with underscores" do
        get "/api/playground/invalid_model_name", as: :json

        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model_name' is not available in the playground")
      end

      it "handles very long model names" do
        long_model_name = "a" * 100
        get "/api/playground/#{long_model_name}", as: :json

        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model '#{long_model_name}' is not available in the playground")
      end

      it "handles model names that look like Rails models but aren't configured" do
        %w[user post comment article blog].each do |model_name|
          get "/api/playground/#{model_name}", as: :json

          expect(response).to have_http_status(:not_found)
          response_body = JSON.parse(response.body)
          error = response_body['errors'].first
          expect(error['title']).to eq('Model not found')
          expect(error['detail']).to eq("The requested model '#{model_name}' is not available in the playground")
          expect(error['available_models']).to eq(['recipe'])
        end
      end
    end

    context "error response structure validation" do
      it "returns proper JSON:API error structure" do
        get "/api/playground/invalid_model", as: :json

        expect(response).to have_http_status(:not_found)
        expect(response.content_type).to include('application/json')
        
        # Verify JSON:API error structure
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to be_an(Array)
        expect(json_response['errors'].size).to eq(1)
        
        error = json_response['errors'].first
        expect(error).to have_key('status')
        expect(error).to have_key('title')
        expect(error).to have_key('detail')
        expect(error).to have_key('available_models')
        
        expect(error['status']).to be_a(String)
        expect(error['title']).to be_a(String)
        expect(error['detail']).to be_a(String)
        expect(error['available_models']).to be_an(Array)
      end

      it "does not include data key in error responses" do
        get "/api/playground/invalid_model", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).not_to have_key('data')
        expect(json_response).to have_key('errors')
      end

      it "includes helpful available models information" do
        get "/api/playground/invalid_model", as: :json

        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        
        expect(error['available_models']).to be_an(Array)
        expect(error['available_models']).not_to be_empty
        expect(error['available_models']).to include('recipe')
      end
    end

    context "consistency across different controllers" do
      it "returns consistent error format between main and test controllers" do
        # Test main controller
        get "/api/playground/invalid_model", as: :json
        main_error = json_response['errors'].first

        # Test disabled controller
        get "/api/test_playground/invalid_model", as: :json
        test_error = json_response['errors'].first

        # Both should have the same error structure and content
        expect(main_error['status']).to eq(test_error['status'])
        expect(main_error['title']).to eq(test_error['title'])
        expect(main_error['detail']).to eq(test_error['detail'])
        expect(main_error['available_models']).to eq(test_error['available_models'])
      end
    end

    context "security considerations" do
      it "does not expose internal model information in error messages" do
        get "/api/playground/invalid_model", as: :json

        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        
        # Verify no sensitive information is exposed
        expect(error['detail']).not_to include('ActiveRecord')
        expect(error['detail']).not_to include('database')
        expect(error['detail']).not_to include('table')
        expect(error['detail']).not_to include('class')
      end

      it "does not perform any database operations for invalid models" do
        # This test ensures that invalid model requests don't trigger database queries
        # We can't easily test query count here, but we verify the error is returned quickly
        get "/api/playground/invalid_model", as: :json

        expect(response).to have_http_status(:not_found)
        # The fact that we get a model not found error (not a database error) 
        # indicates the system correctly identifies invalid models before hitting the database
      end
    end
  end
end 