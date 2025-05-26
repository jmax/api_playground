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
    end

    class_methods do
      # Enables API key protection for all actions in the controller
      def protected_playground!
        self.api_protection_enabled = true
        before_action :validate_api_key
      end
    end

    private

    def validate_api_key
      return unless api_protection_enabled

      token = request.headers['X-API-Key']
      
      if token.blank?
        render_unauthorized('API key is missing')
        return
      end

      api_key = ApiPlayground::ApiKey.valid.find_by(token: token)

      if api_key.nil?
        render_unauthorized('Invalid or expired API key')
        return
      end

      # Update last used timestamp
      api_key.touch_last_used
    end

    def render_unauthorized(message)
      render json: {
        errors: [{
          status: '401',
          title: 'Unauthorized',
          detail: message
        }]
      }, status: :unauthorized
    end
  end
end 