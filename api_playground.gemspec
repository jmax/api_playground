require_relative "lib/api_playground/version"

Gem::Specification.new do |spec|
  spec.name = "api_playground"
  spec.version = ApiPlayground::VERSION
  spec.authors = ["Juan Maria Martinez Arce"]
  spec.email = ["jmartinezarce@gmail.com"]

  spec.summary = "A flexible API playground for Rails applications"
  spec.description = "Provides a configurable API playground with routing macros, concerns, and API key protection"
  spec.homepage = "https://github.com/yourusername/api_playground"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["{app,config,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", ">= 6.1"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "sqlite3"
end 