# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApiPlayground::ApiKeyProtection, type: :controller do
  # Create a test controller that includes the concern
  controller(ActionController::Base) do
    include ApiPlayground::ApiKeyProtection

    def index
      render json: { message: 'success' }
    end
  end

  # Configure routes for the test controller
  before do
    routes.draw do
      get 'index' => 'anonymous#index'
    end

    # Configure ApiPlayground for testing
    ApiPlayground.configure do |config|
      config.api_key_model = 'ApiPlayground::ApiKey'
      config.api_key_field = 'token'
      config.api_key_header = 'X-API-Key'
    end
  end

  # Reset protection state before each test
  before(:each) do
    controller.class.unprotected_playground!
  end

  describe 'protection configuration' do
    it 'is disabled by default' do
      # Create a fresh controller to test default state
      new_controller = Class.new(ActionController::Base) do
        include ApiPlayground::ApiKeyProtection
      end

      expect(new_controller.api_protection_enabled).to be false
    end

    it 'can be enabled via protected_playground!' do
      expect {
        controller.class.protected_playground!
      }.to change { controller.class.api_protection_enabled }.from(false).to(true)
    end

    it 'can be disabled via unprotected_playground!' do
      controller.class.protected_playground!
      expect {
        controller.class.unprotected_playground!
      }.to change { controller.class.api_protection_enabled }.from(true).to(false)
    end

    it 'adds validate_api_key as a before_action with correct condition' do      
      callbacks = controller.class._process_action_callbacks
      validate_key_callback = callbacks.find { |cb| cb.filter == :validate_api_key }
      
      expect(validate_key_callback).to be_present
      expect(validate_key_callback.instance_variable_get(:@if)).to eq([:api_protection_enabled?])
    end
  end

  describe 'API key validation' do
    context 'when protection is disabled' do
      before(:each) do
        # Ensure protection is disabled
        controller.class.unprotected_playground!
        # Verify the state
        expect(controller.class.api_protection_enabled).to be false
        expect(controller.send(:api_protection_enabled?)).to be false
      end

      it 'allows requests without API key' do
        # Make the request
        get :index
        
        # Verify response
        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq('message' => 'success')
      end

      it 'skips the validation callback' do
        expect(controller).not_to receive(:authenticate_api_key!)
        get :index
      end
    end

    context 'when protection is enabled' do
      before(:each) do
        controller.class.protected_playground!
        expect(controller.class.api_protection_enabled).to be true
        expect(controller.send(:api_protection_enabled?)).to be true
      end

      context 'with missing API key' do
        it 'returns unauthorized with error message' do
          get :index

          expect(response).to have_http_status(:unauthorized)
          expect(response.content_type).to include('application/json')

          json_response = JSON.parse(response.body)
          expect(json_response).to eq('error' => 'Invalid or missing API key')
        end
      end

      context 'with invalid API key' do
        before do
          request.headers['X-API-Key'] = 'invalid-key'
          allow(ApiPlayground::ApiKey).to receive(:find_by).with('token' => 'invalid-key').and_return(nil)
        end

        it 'returns unauthorized with error message' do
          get :index

          expect(response).to have_http_status(:unauthorized)
          expect(response.content_type).to include('application/json')

          json_response = JSON.parse(response.body)
          expect(json_response).to eq('error' => 'Invalid or missing API key')
        end
      end

      context 'with expired API key' do
        let(:expired_key) { create(:api_key, expires_at: 1.day.ago) }

        before do
          request.headers['X-API-Key'] = expired_key.token
          allow(ApiPlayground::ApiKey).to receive(:find_by).with('token' => expired_key.token).and_return(expired_key)
          allow(expired_key).to receive(:touch_last_used).and_return(false)
        end

        it 'returns unauthorized with error message' do
          get :index

          expect(response).to have_http_status(:unauthorized)
          expect(response.content_type).to include('application/json')

          json_response = JSON.parse(response.body)
          expect(json_response).to eq('error' => 'Invalid or missing API key')
        end
      end

      context 'with valid API key' do
        let(:api_key) { create(:api_key, expires_at: 1.day.from_now) }

        before do
          request.headers['X-API-Key'] = api_key.token
          allow(ApiPlayground::ApiKey).to receive(:find_by).with('token' => api_key.token).and_return(api_key)
          allow(api_key).to receive(:touch_last_used).and_return(true)
        end

        it 'allows the request' do
          get :index
          expect(response).to have_http_status(:success)
          expect(JSON.parse(response.body)).to eq('message' => 'success')
        end

        it 'updates last_used_at timestamp' do
          expect(api_key).to receive(:touch_last_used).and_return(true)
          get :index
          expect(response).to have_http_status(:success)
        end
      end
    end
  end
end 