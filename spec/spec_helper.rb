require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  
  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Concerns', ['app/controllers/concerns', 'app/models/concerns']
  add_group 'Libraries', 'lib'
end

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../dummy/config/environment', __FILE__)

require 'rspec/rails'
require 'factory_bot_rails'
require 'faker'
require 'database_cleaner/active_record'
require 'shoulda-matchers'

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

# Load support files
Dir[File.join(File.dirname(__FILE__), 'support/**/*.rb')].each { |f| require f }

# Load migrations from dummy app
ActiveRecord::Migrator.migrations_paths = [File.expand_path('../dummy/db/migrate', __FILE__)]
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # Use the new expect syntax
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  # Use the new mock syntax
  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect
    mocks.verify_partial_doubles = true
  end

  # Factory Bot configuration
  config.include FactoryBot::Syntax::Methods

  # Database Cleaner configuration
  config.before(:suite) do
    # Clean the database before running the suite
    ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence")
    ActiveRecord::Base.connection.tables.each do |table|
      next if table == "schema_migrations" || table == "ar_internal_metadata"
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
  end

  config.around(:each) do |example|
    # Use transactions for cleaning
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  # Include Rails route helpers
  config.include Rails.application.routes.url_helpers

  # Disable monkey patching
  config.disable_monkey_patching!

  # Use random order for tests
  config.order = :random

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Show the slowest examples
  config.profile_examples = 10

  # Use color in STDOUT
  config.color = true

  # Use the documentation formatter for detailed output
  config.formatter = :documentation
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end 