require "api_playground/version"
require "api_playground/routing_mapper"
require "api_playground/concern"
require "api_playground/configuration"
require "api_playground/api_protection"
require "api_playground/engine" if defined?(Rails)

module ApiPlayground
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end 