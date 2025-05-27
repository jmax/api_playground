SimpleCov.start 'rails' do
  # Standard filters
  add_filter '/spec/'
  add_filter '/config/'
  
  # Specific file exclusions
  add_filter 'lib/api_playground/version.rb'
  add_filter 'lib/generators/api_playground/install/install_generator.rb'

  # Group definitions
  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Concerns', ['app/controllers/concerns', 'app/models/concerns']
  add_group 'Libraries', 'lib'

  # Configure coverage validation
  minimum_coverage 90
  
  # Don't consider private methods in coverage
  track_files "#{SimpleCov.root}/{app,lib}/**/*.rb" do |file|
    # Skip private method coverage
    file.lines.reject do |line|
      line.strip =~ /^\s*private\b/ ||  # Ignore private keyword
      line.strip =~ /^\s*protected\b/    # Ignore protected keyword
    end
  end
end 