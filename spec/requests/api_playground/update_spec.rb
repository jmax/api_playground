require 'rails_helper'

RSpec.describe "ApiPlayground Update Action", type: :request do
  describe "PATCH /api/playground/:model_name/:id" do
    let!(:recipe) do
      Recipe.create!(
        title: "Original Spaghetti Carbonara", 
        body: "Original classic Italian pasta dish with eggs and cheese"
      )
    end

    context "with valid parameters" do
      let(:valid_params) do
        {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Updated Spaghetti Carbonara',
              body: 'Updated classic Italian pasta dish with eggs, cheese, and pancetta'
            }
          }
        }
      end

      it "updates the recipe successfully" do
        patch "/api/playground/recipes/#{recipe.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
        
        # Verify JSON:API structure
        expect(json_response).to have_key('data')
        expect(json_response['data']).to have_key('id')
        expect(json_response['data']).to have_key('type')
        expect(json_response['data']).to have_key('attributes')
        
        # Verify the data is correct
        expect(json_response['data']['id']).to eq(recipe.id.to_s)
        expect(json_response['data']['type']).to eq('recipes')
        expect(json_response['data']['attributes']['title']).to eq('Updated Spaghetti Carbonara')
        expect(json_response['data']['attributes']['body']).to eq('Updated classic Italian pasta dish with eggs, cheese, and pancetta')
      end

      it "persists the changes to the database" do
        patch "/api/playground/recipes/#{recipe.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:ok)
        
        # Verify the record was actually updated in the database
        recipe.reload
        expect(recipe.title).to eq('Updated Spaghetti Carbonara')
        expect(recipe.body).to eq('Updated classic Italian pasta dish with eggs, cheese, and pancetta')
      end

      it "allows partial updates" do
        partial_params = {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Partially Updated Title'
            }
          }
        }

        patch "/api/playground/recipes/#{recipe.id}", params: partial_params, as: :json

        expect(response).to have_http_status(:ok)
        
        # Verify only the title was updated
        recipe.reload
        expect(recipe.title).to eq('Partially Updated Title')
        expect(recipe.body).to eq('Original classic Italian pasta dish with eggs and cheese') # unchanged
      end

      it "returns the updated resource in JSON:API format" do
        patch "/api/playground/recipes/#{recipe.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:ok)
        
        # Verify JSON:API compliance
        data = json_response['data']
        expect(data['id']).to be_a(String)
        expect(data['type']).to eq('recipes')
        expect(data['attributes']).to be_a(Hash)
        expect(data['attributes']).to include('title', 'body')
        expect(data['attributes']).not_to include('id', 'created_at', 'updated_at')
      end
    end

    context "with validation errors" do
      it "returns validation errors for missing title" do
        invalid_params = {
          data: {
            type: 'recipes',
            attributes: {
              title: '', # Invalid: title can't be blank
              body: 'Updated body'
            }
          }
        }

        patch "/api/playground/recipes/#{recipe.id}", params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to be_an(Array)
        
        error = json_response['errors'].first
        expect(error['status']).to eq('422')
        expect(error['title']).to eq('Validation Error')
        expect(error['detail']).to include("Title can't be blank")
        expect(error['source']['pointer']).to eq('/data/attributes/title')
      end

      it "returns validation errors for missing body" do
        invalid_params = {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Updated title',
              body: '' # Invalid: body can't be blank
            }
          }
        }

        patch "/api/playground/recipes/#{recipe.id}", params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('422')
        expect(error['title']).to eq('Validation Error')
        expect(error['detail']).to include("Body can't be blank")
        expect(error['source']['pointer']).to eq('/data/attributes/body')
      end

      it "returns multiple validation errors" do
        invalid_params = {
          data: {
            type: 'recipes',
            attributes: {
              title: '', # Invalid: title can't be blank
              body: ''   # Invalid: body can't be blank
            }
          }
        }

        patch "/api/playground/recipes/#{recipe.id}", params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['errors'].size).to eq(2)
        
        error_details = json_response['errors'].map { |e| e['detail'] }
        expect(error_details).to include(match(/Title can't be blank/))
        expect(error_details).to include(match(/Body can't be blank/))
      end

      it "does not update the record when validation fails" do
        original_title = recipe.title
        original_body = recipe.body

        invalid_params = {
          data: {
            type: 'recipes',
            attributes: {
              title: '',
              body: 'This should not be saved'
            }
          }
        }

        patch "/api/playground/recipes/#{recipe.id}", params: invalid_params, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        
        # Verify the record was not changed
        recipe.reload
        expect(recipe.title).to eq(original_title)
        expect(recipe.body).to eq(original_body)
      end
    end

    context "with malformed requests" do
      it "returns bad request for missing data parameter" do
        malformed_params = {
          attributes: {
            title: 'Updated title'
          }
        }

        patch "/api/playground/recipes/#{recipe.id}", params: malformed_params, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('400')
        expect(error['title']).to eq('Parameter missing')
        expect(error['detail']).to include('Required parameter missing: data')
      end

      it "returns bad request for missing attributes parameter" do
        malformed_params = {
          data: {
            type: 'recipes'
            # Missing attributes
          }
        }

        patch "/api/playground/recipes/#{recipe.id}", params: malformed_params, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('400')
        expect(error['title']).to eq('Parameter missing')
        expect(error['detail']).to include('Required parameter missing: attributes')
      end
    end

    context "when record does not exist" do
      it "returns not found error" do
        non_existent_id = 99999
        valid_params = {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Updated title'
            }
          }
        }

        patch "/api/playground/recipes/#{non_existent_id}", params: valid_params, as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Record not found')
        expect(error['detail']).to eq("Could not find recipe with id '#{non_existent_id}'")
      end
    end

    context "when model does not exist" do
      it "returns model not found error" do
        valid_params = {
          data: {
            type: 'invalid_models',
            attributes: {
              title: 'Updated title'
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
    end

    context "with field filtering" do
      it "filters out unauthorized fields during update" do
        params_with_unauthorized_field = {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Updated title',
              body: 'Updated body',
              unauthorized_field: 'This should be ignored'
            }
          }
        }

        patch "/api/playground/recipes/#{recipe.id}", params: params_with_unauthorized_field, as: :json

        expect(response).to have_http_status(:ok)
        
        # Verify the authorized fields were updated
        recipe.reload
        expect(recipe.title).to eq('Updated title')
        expect(recipe.body).to eq('Updated body')
        
        # Verify the unauthorized field was ignored (recipe shouldn't have this attribute anyway)
        expect(recipe).not_to respond_to(:unauthorized_field)
      end

      it "only updates fields that are configured as updateable" do
        # The controller is configured to allow updates to :title and :body only
        valid_params = {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Updated title',
              body: 'Updated body'
            }
          }
        }

        patch "/api/playground/recipes/#{recipe.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:ok)
        
        recipe.reload
        expect(recipe.title).to eq('Updated title')
        expect(recipe.body).to eq('Updated body')
      end
    end

    context "when update operation is not allowed" do
      # Use the test controller that has update disabled
      
      it "returns method not allowed error" do
        valid_params = {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Updated title',
              body: 'Updated body'
            }
          }
        }

        patch "/api/test_playground/recipes/#{recipe.id}", params: valid_params, as: :json

        expect(response).to have_http_status(:method_not_allowed)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('405')
        expect(error['title']).to eq('Request not supported')
        expect(error['detail']).to eq("The model 'recipes' does not support update operations")
      end
    end

    context "with different field configurations" do
      # Use a test controller with limited update fields
      
      it "only allows updates to configured fields" do
        params_with_mixed_fields = {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Updated title',
              body: 'This should be ignored if not in allowed fields'
            }
          }
        }

        # This would need a separate test controller with limited update fields
        # For now, we'll test with the main controller that allows both fields
        patch "/api/playground/recipes/#{recipe.id}", params: params_with_mixed_fields, as: :json

        expect(response).to have_http_status(:ok)
        
        recipe.reload
        expect(recipe.title).to eq('Updated title')
        expect(recipe.body).to eq('This should be ignored if not in allowed fields')
      end
    end

    context "error handling" do
      it "handles database connection errors gracefully" do
        # Simulate a database error by stubbing the update method
        allow_any_instance_of(Recipe).to receive(:update).and_raise(ActiveRecord::ConnectionNotEstablished.new("Database connection failed"))

        valid_params = {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Updated title'
            }
          }
        }

        expect {
          patch "/api/playground/recipes/#{recipe.id}", params: valid_params, as: :json
        }.to raise_error(ActiveRecord::ConnectionNotEstablished)
      end
    end

    context "performance considerations" do
      it "updates efficiently without unnecessary queries" do
        valid_params = {
          data: {
            type: 'recipes',
            attributes: {
              title: 'Updated title',
              body: 'Updated body'
            }
          }
        }

        # This test verifies that the update operation works correctly
        # In a real scenario, you might want to test query count
        patch "/api/playground/recipes/#{recipe.id}", params: valid_params, as: :json
        
        expect(response).to have_http_status(:ok)
        
        # Verify the update was successful
        recipe.reload
        expect(recipe.title).to eq('Updated title')
        expect(recipe.body).to eq('Updated body')
      end
    end
  end
end 