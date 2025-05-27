require_relative "lib/api_playground/version"

Gem::Specification.new do |spec|
  spec.name        = "api_playground"
  spec.version     = ApiPlayground::VERSION
  spec.authors     = ["Juan Maria Martinez Arce"]
  spec.email       = ["jmartinezarce@gmail.com"]
  spec.homepage    = "https://github.com/yourusername/api_playground"
  spec.summary     = "A flexible API playground for Rails applications"
  spec.description = "Provides a configurable API playground with routing macros, concerns, and API key protection"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.0.0"
  
  spec.add_development_dependency "rspec-rails", "~> 6.1.0"
  spec.add_development_dependency "simplecov", "~> 0.22.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.4.0"
  spec.add_development_dependency "faker", "~> 3.2.0"
  spec.add_development_dependency "database_cleaner-active_record", "~> 2.1.0"
  spec.add_development_dependency "shoulda-matchers", "~> 6.0.0"
end 