# API Playground

API Playground is a Rails engine that provides a flexible and secure way to create API playgrounds for your Rails models. It includes API key authentication, configurable endpoints, and easy-to-use model integration.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'api_playground'
```

And then execute:
```bash
$ bundle install
```

After installation, run the generator to set up the necessary files:

```bash
$ rails generate api_playground:install
```

This will:
1. Create a migration for the API keys table
2. Set up the initial configuration file

## Setting Up Routes

Add the API Playground routes to your application's `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  # Basic setup with default options
  api_playground_routes

  # Or customize with options
  api_playground_routes do |options|
    options.namespace = :api        # Default namespace for all routes
    options.source = :playground    # Controller name/path
    options.path = 'explorer'       # Custom base path (default: 'playground')
  end

  # You can also mount multiple instances with different configurations
  api_playground_routes path: 'v1/playground', namespace: :v1
  api_playground_routes path: 'v2/playground', namespace: :v2
end
```

This will create the following route structure (with default options):
```
                                Routes for API Playground
      Path                      Verb    Controller#Action
      /api/playground/:model    GET     api/playground#index
      /api/playground/:model    POST    api/playground#create
      /api/playground/:model/:id GET    api/playground#show
      /api/playground/:model/:id PATCH  api/playground#update
      /api/playground/:model/:id DELETE api/playground#destroy
```

## Configuration

Create an initializer at `config/initializers/api_playground.rb`:

```ruby
ApiPlayground.configure do |config|
  # Header name for API key authentication (default: 'X-API-Key')
  config.api_key_header = 'X-API-Key'
  
  # Model class for API keys (default: 'ApiPlayground::ApiKey')
  config.api_key_model = 'ApiPlayground::ApiKey'
  
  # Field name for the API key token (default: 'token')
  config.api_key_field = 'token'
  
  # Default API namespace (default: :api)
  config.default_namespace = :api
  
  # Default source name (default: :playground)
  config.default_source = :playground
end
```

## Managing API Keys

API keys are managed through the `ApiPlayground::ApiKey` model. Here are some common operations:

```ruby
# Create a new API key (token is automatically generated)
api_key = ApiPlayground::ApiKey.create!(expires_at: 30.days.from_now)

# Find valid API keys
valid_keys = ApiPlayground::ApiKey.valid

# Check if a token is valid
ApiPlayground::ApiKey.valid_token?('your-token-here')

# Get an API key's details
api_key = ApiPlayground::ApiKey.find_by(token: 'your-token-here')
api_key.expired?     # Check if expired
api_key.last_used_at # Last usage timestamp
```

## Usage

### 1. Protecting Controllers

To require API key authentication for your controllers:

```ruby
class Api::PlaygroundController < ApplicationController
  include ApiPlayground::ApiKeyProtection
  protected_playground!
  
  # ... your actions ...
end
```

### 2. Setting Up Model Playgrounds

Define playground endpoints for your models with customizable options:

```ruby
class Api::PlaygroundController < ApplicationController
  include ApiPlayground
  include ApiPlayground::ApiKeyProtection

  protected_playground!

  playground_for :recipe,
                attributes: [:title, :summary, :body],
                relationships: [:author, :books],
                requests: {
                  create: { fields: [:title, :summary, :body, :author_id] },
                  update: { fields: [:title, :summary, :body] },
                  delete: true
                },
                filters: [
                  { field: 'title', type: :partial },
                  { field: 'summary', type: :partial },
                  { field: 'author_id', type: :exact }
                ],
                pagination: { page_size: 20 }
end
```

### Available Options

#### Attributes
- Specify which model attributes to expose
- Support for nested attributes and custom formatters

#### Relationships
- Define associated models to include
- Automatic handling of includes for better performance

#### Requests
- Configure create/update field whitelisting
- Enable/disable delete operations
- Custom validation handling

#### Filters
- `:partial` - Case-insensitive partial matching
- `:exact` - Exact value matching
- Custom filter types supported

#### Pagination
- Configure page size
- Enable/disable total count for performance
- Disable pagination entirely with `enabled: false`

## API Endpoints

For each model configured with `playground_for`, the following endpoints are automatically created:

```
GET    /api/playground/:model     # Index with filtering and pagination
GET    /api/playground/:model/:id # Show specific record
POST   /api/playground/:model     # Create new record
PATCH  /api/playground/:model/:id # Update existing record
DELETE /api/playground/:model/:id # Delete record (if enabled)
```

## Security

- All endpoints require a valid API key
- Keys automatically expire based on the configured duration
- Last used timestamp is tracked for auditing
- Tokens are securely generated using `SecureRandom.base58`

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/api_playground.

## License

The gem is available as open source under the terms of the MIT License. 