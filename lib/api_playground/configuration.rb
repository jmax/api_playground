module ApiPlayground
  class Configuration
    attr_accessor :api_key_header,
                 :api_key_model,
                 :api_key_field,
                 :default_namespace,
                 :default_source

    def initialize
      @api_key_header = 'X-API-Key'
      @api_key_model = 'ApiPlayground::ApiKey'
      @api_key_field = 'token'
      @default_namespace = :api
      @default_source = :playground
    end
  end
end 