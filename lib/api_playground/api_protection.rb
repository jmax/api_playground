module ApiPlayground
  module ApiProtection
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_api_key!
    end

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
      model.exists?(field => api_key)
    end

    def api_key
      request.headers[ApiPlayground.configuration.api_key_header]
    end
  end
end 