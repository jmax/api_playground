require "bundler/gem_tasks"
require "rspec/core/rake_task"

# Load Rails tasks for the dummy app
APP_RAKEFILE = File.expand_path("spec/dummy/Rakefile", __dir__)
load 'rails/tasks/engine.rake'
load 'rails/tasks/statistics.rake'

# Load all custom rake tasks
Dir[File.join(File.dirname(__FILE__), 'lib/tasks/**/*.rake')].each { |f| load f }

RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_opts = ['--color', '--format', 'documentation']
end

task :prepare_test_env do
  ENV["RAILS_ENV"] = "test"
  require File.expand_path("spec/dummy/config/environment.rb")
  
  # Load migrations path
  ActiveRecord::Migrator.migrations_paths = [
    File.expand_path("spec/dummy/db/migrate", __dir__)
  ]
  
  # Create and migrate test database
  begin
    ActiveRecord::Tasks::DatabaseTasks.create_current
    ActiveRecord::Migration.maintain_test_schema!
  rescue => e
    puts "Warning: #{e.message}"
  end
end

# Make sure test environment is prepared before running specs
task spec: :prepare_test_env

task default: :spec 