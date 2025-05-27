# frozen_string_literal: true

module ApiPlayground
  # Provides API key protection for controllers.
  # When included and enabled, requires a valid API key in the X-API-Key header.
  #
  # @example Enable protection in a controller
  #   class Api::PlaygroundController < ApplicationController
  #     include ApiPlayground::ApiKeyProtection
  #     protected_playground!
  #   end
  module ApiKeyProtection
    extend ActiveSupport::Concern

    included do
      class_attribute :api_protection_enabled, default: false
      before_action :validate_api_key, if: :api_protection_enabled?
    end

    module ClassMethods
      # Enables API key protection for all actions in the controller
      def protected_playground!
        self.api_protection_enabled = true
      end

      # Disables API key protection for all actions in the controller
      def unprotected_playground!
        self.api_protection_enabled = false
      end
    end

    protected

    def validate_api_key
      token = request.headers['X-API-Key']
      
      if token.blank?
        render_api_error
        return false
      end

      api_key = ApiPlayground::ApiKey.find_by(token: token)

      if api_key.nil? || api_key.expired?
        render_api_error
        return false
      end

      api_key.touch_last_used
      true
    end

    private

    def render_api_error
      render json: {
        error: 'Invalid or missing API key'
      }, status: :unauthorized, content_type: 'application/json'
    end

    def api_protection_enabled?
      self.class.api_protection_enabled == true
    end
  end
end 