require 'rails/generators'
require 'rails/generators/migration'

module ApiPlayground
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      def self.next_migration_number(path)
        next_migration_number = current_migration_number(path) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def copy_migration
        migration_template(
          'create_api_playground_api_keys.rb.erb',
          'db/migrate/create_api_playground_api_keys.rb'
        )
      end
    end
  end
end 