require 'rails_helper'

RSpec.describe "ApiPlayground Show Action", type: :request do
  describe "GET /api/playground/:model_name/:id" do
    let!(:recipe) do
      Recipe.create!(
        title: "Spaghetti Carbonara", 
        body: "Classic Italian pasta dish with eggs and cheese"
      )
    end

    context "with valid parameters" do
      it "returns the recipe successfully" do
        get "/api/playground/recipes/#{recipe.id}", as: :json

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
        expect(json_response['data']['attributes']['title']).to eq('Spaghetti Carbonara')
        expect(json_response['data']['attributes']['body']).to eq('Classic Italian pasta dish with eggs and cheese')
      end

      it "returns the correct JSON:API response format" do
        get "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:ok)
        
        # Verify JSON:API compliance
        data = json_response['data']
        expect(data['id']).to be_a(String)
        expect(data['type']).to eq('recipes')
        expect(data['attributes']).to be_a(Hash)
        expect(data['attributes']).to include('title', 'body')
        expect(data['attributes']).not_to include('id', 'created_at', 'updated_at')
      end

      it "includes metadata in the response" do
        get "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key('meta')
        
        meta = json_response['meta']
        expect(meta).to have_key('available_attributes')
        expect(meta).to have_key('available_models')
        expect(meta['available_models']).to eq(['recipe'])
      end

      it "handles different record IDs correctly" do
        recipe2 = Recipe.create!(title: "Pasta Bolognese", body: "Rich meat sauce pasta")
        
        get "/api/playground/recipes/#{recipe2.id}", as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['id']).to eq(recipe2.id.to_s)
        expect(json_response['data']['attributes']['title']).to eq('Pasta Bolognese')
        expect(json_response['data']['attributes']['body']).to eq('Rich meat sauce pasta')
      end
    end

    context "when record does not exist" do
      it "returns not found error" do
        non_existent_id = 99999

        get "/api/playground/recipes/#{non_existent_id}", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Record not found')
        expect(error['detail']).to eq("Could not find recipe with id '#{non_existent_id}'")
      end

      it "handles invalid ID formats gracefully" do
        invalid_id = "not-a-number"

        get "/api/playground/recipes/#{invalid_id}", as: :json

        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        expect(error['detail']).to eq("Could not find recipe with id '#{invalid_id}'")
      end

      it "handles very large ID numbers" do
        large_id = 999999999999999

        get "/api/playground/recipes/#{large_id}", as: :json

        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        expect(error['detail']).to eq("Could not find recipe with id '#{large_id}'")
      end
    end

    context "when model does not exist" do
      it "returns model not found error" do
        get "/api/playground/invalid_model/#{recipe.id}", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end
    end

    context "with field filtering and attribute grouping" do
      it "returns only configured attributes" do
        get "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:ok)
        
        attributes = json_response['data']['attributes']
        expect(attributes.keys).to match_array(['title', 'body'])
        expect(attributes).not_to include('id', 'created_at', 'updated_at')
      end

      it "handles attribute grouping correctly" do
        # Test with the main controller that has ungrouped attributes
        get "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:ok)
        
        # Verify attributes are present and not nested in groups
        attributes = json_response['data']['attributes']
        expect(attributes).to have_key('title')
        expect(attributes).to have_key('body')
        expect(attributes).not_to have_key('basic_info') # No grouping
      end

      it "excludes unauthorized fields from response" do
        get "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:ok)
        
        # Verify only authorized fields are returned
        attributes = json_response['data']['attributes']
        expect(attributes.keys).to eq(['title', 'body'])
        
        # Verify internal Rails attributes are not exposed
        expect(attributes).not_to include('id', 'created_at', 'updated_at')
      end
    end

    context "with relationships" do
      # Note: Our Recipe model doesn't have associations, but if it did:
      
      it "handles records without relationships" do
        get "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:ok)
        
        # Verify no relationships section since Recipe has no associations
        expect(json_response['data']).not_to have_key('relationships')
      end

      # If relationships existed, we would test:
      # it "includes relationship data when configured" do
      #   get "/api/playground/recipes/#{recipe.id}", as: :json
      #   
      #   expect(response).to have_http_status(:ok)
      #   expect(json_response['data']).to have_key('relationships')
      # end
    end

    context "error handling" do
      it "handles database connection errors gracefully" do
        # Simulate a database error by stubbing the find method
        allow(Recipe).to receive(:find).and_raise(ActiveRecord::ConnectionNotEstablished.new("Database connection failed"))

        expect {
          get "/api/playground/recipes/#{recipe.id}", as: :json
        }.to raise_error(ActiveRecord::ConnectionNotEstablished)
      end

      it "handles database query errors" do
        # Simulate a database query error
        allow(Recipe).to receive(:find).and_raise(ActiveRecord::StatementInvalid.new("Database statement invalid"))

        expect {
          get "/api/playground/recipes/#{recipe.id}", as: :json
        }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end

    context "performance considerations" do
      it "retrieves single record efficiently" do
        # This test verifies that the show operation works correctly
        # In a real scenario, you might want to test query count
        get "/api/playground/recipes/#{recipe.id}", as: :json
        
        expect(response).to have_http_status(:ok)
        expect(json_response['data']['id']).to eq(recipe.id.to_s)
      end

      it "handles multiple show requests correctly" do
        recipe2 = Recipe.create!(title: "Recipe 2", body: "Body 2")
        recipe3 = Recipe.create!(title: "Recipe 3", body: "Body 3")

        # Make multiple show requests and verify each one independently
        get "/api/playground/recipes/#{recipe.id}", as: :json
        expect(response).to have_http_status(:ok)
        first_response = JSON.parse(response.body)
        expect(first_response['data']['attributes']['title']).to eq('Spaghetti Carbonara')

        get "/api/playground/recipes/#{recipe2.id}", as: :json
        expect(response).to have_http_status(:ok)
        second_response = JSON.parse(response.body)
        expect(second_response['data']['attributes']['title']).to eq('Recipe 2')

        get "/api/playground/recipes/#{recipe3.id}", as: :json
        expect(response).to have_http_status(:ok)
        third_response = JSON.parse(response.body)
        expect(third_response['data']['attributes']['title']).to eq('Recipe 3')
      end
    end

    context "edge cases" do
      it "handles deleted records appropriately" do
        # Delete the record first
        recipe.destroy

        get "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        expect(error['detail']).to eq("Could not find recipe with id '#{recipe.id}'")
      end

      it "handles records with nil attributes" do
        # Create a recipe with minimal data (if validations allow)
        # Since our Recipe requires title and body, we'll test with valid but minimal data
        minimal_recipe = Recipe.create!(title: "Minimal", body: "Basic")

        get "/api/playground/recipes/#{minimal_recipe.id}", as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']['title']).to eq('Minimal')
        expect(json_response['data']['attributes']['body']).to eq('Basic')
      end

      it "handles records with special characters in attributes" do
        special_recipe = Recipe.create!(
          title: "Recipe with 'quotes' & symbols!",
          body: "Body with <html> tags & special chars: éñ"
        )

        get "/api/playground/recipes/#{special_recipe.id}", as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']['title']).to eq("Recipe with 'quotes' & symbols!")
        expect(json_response['data']['attributes']['body']).to eq("Body with <html> tags & special chars: éñ")
      end
    end

    context "security considerations" do
      it "only returns data for the specified record" do
        recipe2 = Recipe.create!(title: "Other Recipe", body: "Should not be returned")

        get "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['id']).to eq(recipe.id.to_s)
        expect(json_response['data']['attributes']['title']).to eq('Spaghetti Carbonara')
        expect(json_response['data']['attributes']['title']).not_to eq('Other Recipe')
      end

      it "does not expose sensitive model information" do
        get "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:ok)
        
        # Verify internal Rails attributes are not exposed
        attributes = json_response['data']['attributes']
        expect(attributes).not_to include('id', 'created_at', 'updated_at')
        
        # Verify no internal model methods are exposed
        expect(json_response['data']).not_to have_key('methods')
        expect(json_response['data']).not_to have_key('class')
      end

      it "requires explicit ID in the URL" do
        # Test that we can't show without specifying an ID
        # This route actually matches the index action, not show
        get "/api/playground/recipes/", as: :json
        
        # This should return the index (list) response, not a show response
        # So we verify it's not a single record response
        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key('data')
        # Index returns an array, show returns an object
        expect(json_response['data']).to be_an(Array)
      end
    end

    context "content type and headers" do
      it "returns correct content type" do
        get "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
      end

      it "handles requests without explicit JSON format" do
        get "/api/playground/recipes/#{recipe.id}"

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')
      end
    end
  end
end 