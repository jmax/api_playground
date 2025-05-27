# API Playground

A Rails engine for managing API keys and protecting API endpoints.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'api_playground'
```

And then execute:
```bash
$ bundle install
```

Or install it yourself as:
```bash
$ gem install api_playground
```

Then run the installation generator:
```bash
$ rails generate api_playground:install
```

This will:
1. Create the necessary migrations for API keys
2. Set up initial configuration

## Configuration

Configure API Playground in an initializer:

```ruby
# config/initializers/api_playground.rb
ApiPlayground.configure do |config|
  config.api_key_model = 'ApiPlayground::ApiKey'  # Model to use for API keys
  config.api_key_field = 'token'                  # Field that stores the API key
  config.api_key_header = 'X-API-Key'            # Header to check for API key
end
```

## Usage

### Protecting Controllers

Include the protection in your controllers:

```ruby
class ApiController < ApplicationController
  include ApiPlayground::ApiKeyProtection
end
```

By default, API protection is disabled. You can enable it in two ways:

1. Enable for all actions in a controller:
```ruby
class ApiController < ApplicationController
  include ApiPlayground::ApiKeyProtection
  protected_playground!
end
```

2. Enable/disable dynamically:
```ruby
class ApiController < ApplicationController
  include ApiPlayground::ApiKeyProtection
  
  # Enable protection for specific actions
  before_action :enable_protection, only: [:create, :update, :destroy]
  
  private
  
  def enable_protection
    self.class.protected_playground!
  end
  
  def disable_protection
    self.class.unprotected_playground!
  end
end
```

When protection is enabled, requests must include a valid API key in the configured header (default: 'X-API-Key').
Invalid or missing API keys will receive a 401 Unauthorized response.

### Managing API Keys

API keys can be managed through the `ApiPlayground::ApiKey` model:

```ruby
# Create a new API key
api_key = ApiPlayground::ApiKey.create(expires_at: 1.year.from_now)

# Access the token
api_key.token

# Check if expired
api_key.expired?

# Get last used timestamp
api_key.last_used_at
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for collaboration.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT). 