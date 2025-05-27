# frozen_string_literal: true

module ApiPlayground
  # Internal module for API key validation logic.
  # This module is used by ApiKeyProtection concern and should not be included directly.
  module ApiProtection
    extend ActiveSupport::Concern

    private

    def authenticate_api_key!
      unless valid_api_key?
        render json: { error: 'Invalid or missing API key' }, status: :unauthorized
      end
    end

    def valid_api_key?
      return false unless api_key.present?

      model = ApiPlayground.configuration.api_key_model.constantize
      field = ApiPlayground.configuration.api_key_field
      
      # Find the key and update last_used_at if valid
      key_record = model.find_by(field => api_key)
      if key_record&.touch_last_used
        true
      else
        false
      end
    end

    def api_key
      request.headers[ApiPlayground.configuration.api_key_header]
    end
  end
end 