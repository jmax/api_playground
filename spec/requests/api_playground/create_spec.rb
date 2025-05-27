require 'rails_helper'

RSpec.describe "ApiPlayground Create Action", type: :request do
  describe "POST /api/playground/:model_name" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Delicious Pasta',
              body: 'A wonderful pasta recipe with fresh ingredients'
            }
          }
        }
      end

      it "creates a new recipe successfully" do
        expect {
          post "/api/playground/recipe", params: valid_params, as: :json
        }.to change(Recipe, :count).by(1)

        expect(response).to have_http_status(:created)
        
        # Verify JSON:API structure
        expect(json_response).to have_key('data')
        expect(json_response['data']).to have_key('type')
        expect(json_response['data']).to have_key('id')
        expect(json_response['data']).to have_key('attributes')
        
        # Verify response content
        expect(json_response['data']['type']).to eq('recipes')
        expect(json_response['data']['attributes']['title']).to eq('Delicious Pasta')
        expect(json_response['data']['attributes']['body']).to eq('A wonderful pasta recipe with fresh ingredients')
        
        # Verify the record was actually created in the database
        created_recipe = Recipe.last
        expect(created_recipe.title).to eq('Delicious Pasta')
        expect(created_recipe.body).to eq('A wonderful pasta recipe with fresh ingredients')
      end

      it "returns the correct JSON:API response format" do
        post "/api/playground/recipe", params: valid_params, as: :json

        expect(response).to have_http_status(:created)
        expect(response.content_type).to include('application/json')
        
        # Verify JSON:API compliance
        expect(json_response['data']['type']).to eq('recipes')
        expect(json_response['data']['id']).to be_present
        expect(json_response['data']['attributes']).to be_a(Hash)
        expect(json_response['data']['attributes']).to include('title', 'body')
      end
    end

    context "with invalid parameters" do
      context "when title is missing" do
        let(:invalid_params) do
          {
            data: {
              type: 'recipes',
              attributes: {
                body: 'A recipe without a title'
              }
            }
          }
        end

        it "returns validation errors" do
          post "/api/playground/recipe", params: invalid_params, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response).to have_key('errors')
          expect(json_response['errors']).to be_an(Array)
          
          error = json_response['errors'].first
          expect(error['status']).to eq('422')
          expect(error['title']).to eq('Validation Error')
          expect(error['detail']).to include("Title can't be blank")
          expect(error['source']['pointer']).to eq('/data/attributes/title')
        end

        it "does not create a record" do
          expect {
            post "/api/playground/recipe", params: invalid_params, as: :json
          }.not_to change(Recipe, :count)
        end
      end

      context "when body is missing" do
        let(:invalid_params) do
          {
            data: {
              type: 'recipes',
              attributes: {
                title: 'Recipe without body'
              }
            }
          }
        end

        it "returns validation errors for body" do
          post "/api/playground/recipe", params: invalid_params, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          
          error = json_response['errors'].find { |e| e['detail'].include?("Body can't be blank") }
          expect(error).to be_present
          expect(error['source']['pointer']).to eq('/data/attributes/body')
        end
      end

      context "when multiple fields are invalid" do
        let(:invalid_params) do
          {
            data: {
              type: 'recipes',
              attributes: {
                title: '',
                body: ''
              }
            }
          }
        end

        it "returns multiple validation errors" do
          post "/api/playground/recipe", params: invalid_params, as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(json_response['errors'].length).to eq(2)
          
          error_details = json_response['errors'].map { |e| e['detail'] }
          expect(error_details).to include("Title can't be blank")
          expect(error_details).to include("Body can't be blank")
        end
      end
    end

    context "with malformed request data" do
      context "when data parameter is missing" do
        it "returns parameter missing error" do
          post "/api/playground/recipe", params: {}, as: :json

          expect(response).to have_http_status(:bad_request)
          expect(json_response).to have_key('errors')
          
          error = json_response['errors'].first
          expect(error['status']).to eq('400')
          expect(error['title']).to eq('Parameter missing')
          expect(error['detail']).to eq('Required parameter missing: data')
          expect(error['source']['pointer']).to eq('/data/attributes')
        end
      end

      context "when attributes parameter is missing" do
        let(:malformed_params) do
          {
            data: {
              type: 'recipes'
            }
          }
        end

        it "returns parameter missing error for attributes" do
          post "/api/playground/recipe", params: malformed_params, as: :json

          expect(response).to have_http_status(:bad_request)
          
          error = json_response['errors'].first
          expect(error['status']).to eq('400')
          expect(error['title']).to eq('Parameter missing')
          expect(error['detail']).to eq('Required parameter missing: attributes')
          expect(error['source']['pointer']).to eq('/data/attributes')
        end
      end
    end

    context "when model does not exist" do
      let(:valid_params) do
        {
          data: {
            type: 'invalid_models',
            attributes: {
              title: 'Test',
              body: 'Test body'
            }
          }
        }
      end

      it "returns model not found error" do
        post "/api/playground/invalid_model", params: valid_params, as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end
    end

    context "when create operation is not allowed" do
      it "returns method not allowed error" do
        valid_params = {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Spaghetti Carbonara',
              body: 'Classic Italian pasta dish with eggs and cheese'
            }
          }
        }

        post "/api/test_playground/recipes", params: valid_params, as: :json

        expect(response).to have_http_status(:method_not_allowed)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('405')
        expect(error['title']).to eq('Request not supported')
        expect(error['detail']).to eq("The model 'recipes' does not support create operations")
      end
    end

    context "with extra attributes not in allowed fields" do
      let(:params_with_extra_fields) do
        {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Valid Recipe',
              body: 'Valid body',
              unauthorized_field: 'This should be filtered out'
            }
          }
        }
      end

      it "filters out unauthorized fields and creates the record" do
        expect {
          post "/api/playground/recipe", params: params_with_extra_fields, as: :json
        }.to change(Recipe, :count).by(1)

        expect(response).to have_http_status(:created)
        
        created_recipe = Recipe.last
        expect(created_recipe.title).to eq('Valid Recipe')
        expect(created_recipe.body).to eq('Valid body')
        
        # Verify the unauthorized field was not set (assuming Recipe doesn't have this attribute)
        expect(created_recipe).not_to respond_to(:unauthorized_field)
      end
    end
  end
end 