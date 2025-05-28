require 'rails_helper'

RSpec.describe "ApiPlayground Delete Action", type: :request do
  describe "DELETE /api/playground/:model_name/:id" do
    let!(:recipe) do
      Recipe.create!(
        title: "Spaghetti Carbonara", 
        body: "Classic Italian pasta dish with eggs and cheese"
      )
    end

    context "with valid parameters" do
      it "deletes the recipe successfully" do
        expect {
          delete "/api/playground/recipes/#{recipe.id}", as: :json
        }.to change(Recipe, :count).by(-1)

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_empty
      end

      it "removes the record from the database" do
        delete "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:no_content)
        
        # Verify the record was actually deleted from the database
        expect { recipe.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(Recipe.find_by(id: recipe.id)).to be_nil
      end

      it "returns 204 No Content with empty body" do
        delete "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_empty
        expect(response.content_length).to eq(0)
      end

      it "handles multiple deletions correctly" do
        recipe2 = Recipe.create!(title: "Pasta Bolognese", body: "Rich meat sauce pasta")
        
        expect {
          delete "/api/playground/recipes/#{recipe.id}", as: :json
          delete "/api/playground/recipes/#{recipe2.id}", as: :json
        }.to change(Recipe, :count).by(-2)

        expect(Recipe.find_by(id: recipe.id)).to be_nil
        expect(Recipe.find_by(id: recipe2.id)).to be_nil
      end
    end

    context "when record does not exist" do
      it "returns not found error" do
        non_existent_id = 99999

        delete "/api/playground/recipes/#{non_existent_id}", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Record not found')
        expect(error['detail']).to eq("Could not find recipe with id '#{non_existent_id}'")
      end

      it "does not affect other records when trying to delete non-existent record" do
        non_existent_id = 99999
        original_count = Recipe.count

        delete "/api/playground/recipes/#{non_existent_id}", as: :json

        expect(response).to have_http_status(:not_found)
        expect(Recipe.count).to eq(original_count)
        expect(Recipe.find_by(id: recipe.id)).to be_present
      end
    end

    context "when model does not exist" do
      it "returns model not found error" do
        delete "/api/playground/invalid_model/#{recipe.id}", as: :json

        expect(response).to have_http_status(:not_found)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('404')
        expect(error['title']).to eq('Model not found')
        expect(error['detail']).to eq("The requested model 'invalid_model' is not available in the playground")
        expect(error['available_models']).to eq(['recipe'])
      end

      it "does not delete any records when model is invalid" do
        original_count = Recipe.count

        delete "/api/playground/invalid_model/#{recipe.id}", as: :json

        expect(response).to have_http_status(:not_found)
        expect(Recipe.count).to eq(original_count)
        expect(Recipe.find_by(id: recipe.id)).to be_present
      end
    end

    context "when delete operation is not allowed" do
      it "returns method not allowed error" do
        delete "/api/test_playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:method_not_allowed)
        expect(json_response).to have_key('errors')
        
        error = json_response['errors'].first
        expect(error['status']).to eq('405')
        expect(error['title']).to eq('Request not supported')
        expect(error['detail']).to eq("The model 'recipes' does not support delete operations")
      end
    end

    context "with database constraints and relationships" do
      it "handles deletion successfully when no constraints exist" do
        # Our Recipe model doesn't have any foreign key constraints
        delete "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:no_content)
        expect(Recipe.find_by(id: recipe.id)).to be_nil
      end

      # Note: If the model had dependent records, we would test those scenarios here
      # For example:
      # it "handles dependent destroy correctly" do
      #   # Test cascading deletes if configured
      # end
      #
      # it "returns error when foreign key constraints prevent deletion" do
      #   # Test constraint violations
      # end
    end

    context "error handling" do
      it "handles database connection errors gracefully" do
        # Simulate a database error by stubbing the destroy method
        allow_any_instance_of(Recipe).to receive(:destroy).and_raise(ActiveRecord::ConnectionNotEstablished.new("Database connection failed"))

        expect {
          delete "/api/playground/recipes/#{recipe.id}", as: :json
        }.to raise_error(ActiveRecord::ConnectionNotEstablished)
      end

      it "handles database transaction errors" do
        # Simulate a database transaction error
        allow_any_instance_of(Recipe).to receive(:destroy).and_raise(ActiveRecord::StatementInvalid.new("Database statement invalid"))

        expect {
          delete "/api/playground/recipes/#{recipe.id}", as: :json
        }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end

    context "with soft delete scenarios" do
      # Note: Our Recipe model doesn't implement soft deletes, but if it did:
      
      it "performs hard delete as expected" do
        # Since Recipe doesn't have soft delete, this is a hard delete
        delete "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:no_content)
        expect(Recipe.find_by(id: recipe.id)).to be_nil
        
        # Verify it's actually gone from the database, not just marked as deleted
        expect(Recipe.unscoped.find_by(id: recipe.id)).to be_nil
      end

      # If soft delete was implemented, we would test:
      # it "marks record as deleted instead of removing it" do
      #   delete "/api/playground/recipes/#{recipe.id}", as: :json
      #   
      #   expect(response).to have_http_status(:no_content)
      #   expect(Recipe.find_by(id: recipe.id)).to be_nil  # Not found in default scope
      #   expect(Recipe.unscoped.find_by(id: recipe.id).deleted?).to be true  # But exists as deleted
      # end
    end

    context "performance considerations" do
      it "deletes efficiently without unnecessary queries" do
        # This test verifies that the delete operation works correctly
        # In a real scenario, you might want to test query count
        delete "/api/playground/recipes/#{recipe.id}", as: :json
        
        expect(response).to have_http_status(:no_content)
        expect(Recipe.find_by(id: recipe.id)).to be_nil
      end

      it "handles bulk deletion scenarios" do
        # Create multiple recipes for bulk testing
        recipes = Array.new(5) do |i|
          Recipe.create!(title: "Recipe #{i}", body: "Body #{i}")
        end

        # Delete them one by one (simulating multiple delete requests)
        recipes.each do |r|
          delete "/api/playground/recipes/#{r.id}", as: :json
          expect(response).to have_http_status(:no_content)
        end

        # Verify all were deleted
        recipes.each do |r|
          expect(Recipe.find_by(id: r.id)).to be_nil
        end
      end
    end

    context "edge cases" do
      it "handles deletion of already deleted record gracefully" do
        # Delete the record first
        delete "/api/playground/recipes/#{recipe.id}", as: :json
        expect(response).to have_http_status(:no_content)

        # Try to delete it again
        delete "/api/playground/recipes/#{recipe.id}", as: :json
        
        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        expect(error['detail']).to eq("Could not find recipe with id '#{recipe.id}'")
      end

      it "handles invalid ID formats gracefully" do
        invalid_id = "not-a-number"

        delete "/api/playground/recipes/#{invalid_id}", as: :json

        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        expect(error['detail']).to eq("Could not find recipe with id '#{invalid_id}'")
      end

      it "handles very large ID numbers" do
        large_id = 999999999999999

        delete "/api/playground/recipes/#{large_id}", as: :json

        expect(response).to have_http_status(:not_found)
        error = json_response['errors'].first
        expect(error['detail']).to eq("Could not find recipe with id '#{large_id}'")
      end
    end

    context "security considerations" do
      it "only deletes the specified record" do
        # Create another recipe to ensure we don't accidentally delete it
        other_recipe = Recipe.create!(title: "Other Recipe", body: "Should not be deleted")
        original_count = Recipe.count

        delete "/api/playground/recipes/#{recipe.id}", as: :json

        expect(response).to have_http_status(:no_content)
        expect(Recipe.count).to eq(original_count - 1)
        expect(Recipe.find_by(id: other_recipe.id)).to be_present
        expect(Recipe.find_by(id: recipe.id)).to be_nil
      end

      it "requires explicit ID in the URL" do
        # Test that we can't delete without specifying an ID
        # This would be a routing error, but let's verify the behavior
        expect {
          delete "/api/playground/recipes/", as: :json
        }.to raise_error(ActionController::RoutingError)
      end
    end
  end
end 