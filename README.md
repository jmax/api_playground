# API Playground

A Rails engine that provides a flexible API playground for exploring and testing your Rails models through a JSON:API compliant interface.

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

## Setup

### 1. Create a Controller

Create a controller that includes the `ApiPlayground` concern:

```ruby
# app/controllers/api/playground_controller.rb
module Api
  class PlaygroundController < ApplicationController
    include ApiPlayground

    # Configure the playground for your models
    playground_for :recipe,
                  attributes: [:title, :body, :description],
                  requests: {
                    create: { fields: [:title, :body] },
                    update: { fields: [:title, :body] },
                    delete: true
                  },
                  pagination: { enabled: true, page_size: 20 }

    # You can configure multiple models
    playground_for :user,
                  attributes: [:name, :email],
                  requests: {
                    create: false,  # Disable create operations
                    update: { fields: [:name] },
                    delete: false   # Disable delete operations
                  }
  end
end
```

### 2. Add Routes

Add routes to your `config/routes.rb` using the `api_playground_routes` macro:

```ruby
Rails.application.routes.draw do
  namespace :api do
    api_playground_routes controller: 'playground'
  end
end
```

This macro automatically creates all the necessary routes:
- `GET /api/playground/:model_name` → `playground#discover` (Index/List)
- `GET /api/playground/:model_name/:id` → `playground#discover` (Show)
- `POST /api/playground/:model_name` → `playground#create` (Create)
- `PATCH /api/playground/:model_name/:id` → `playground#update` (Update)
- `DELETE /api/playground/:model_name/:id` → `playground#destroy` (Delete)

#### Custom Route Configuration

You can customize the routes by passing additional options:

```ruby
Rails.application.routes.draw do
  namespace :api do
    # Custom path prefix
    api_playground_routes controller: 'playground', path: 'explore'
    # Routes will be: /api/explore/:model_name, etc.
    
    # Multiple playground controllers
    api_playground_routes controller: 'admin_playground', path: 'admin'
    api_playground_routes controller: 'public_playground', path: 'public'
  end
end
```

#### Manual Route Definition (Alternative)

If you prefer to define routes manually or need custom routing:

```ruby
Rails.application.routes.draw do
  namespace :api do
    scope :playground do
      get ':model_name', to: 'playground#discover'           # Index/List
      get ':model_name/:id', to: 'playground#discover'      # Show
      post ':model_name', to: 'playground#create'           # Create
      patch ':model_name/:id', to: 'playground#update'      # Update
      delete ':model_name/:id', to: 'playground#destroy'    # Delete
    end
  end
end
```

### 3. Configure Your Models

Ensure your models are properly set up with validations:

```ruby
# app/models/recipe.rb
class Recipe < ApplicationRecord
  validates :title, presence: true
  validates :body, presence: true
end
```

## Configuration Options

### Basic Configuration

```ruby
playground_for :model_name,
              attributes: [:field1, :field2],           # Fields to expose
              requests: { ... },                        # CRUD operations config
              pagination: { ... },                      # Pagination settings
              filters: [...],                          # Available filters
              relationships: [...]                     # Model associations
```

### Attributes Configuration

Control which model attributes are exposed:

```ruby
# Simple list (ungrouped)
attributes: [:title, :body, :created_at]

# Grouped attributes
attributes: {
  basic_info: [:title, :body],
  metadata: [:created_at, :updated_at],
  ungrouped: [:status]
}
```

### Request Operations

Configure which CRUD operations are allowed:

```ruby
requests: {
  create: { fields: [:title, :body] },    # Allow create with specific fields
  update: { fields: [:title] },           # Allow update with limited fields
  delete: true                            # Allow delete operations
}

# Disable specific operations
requests: {
  create: false,    # Disable create
  update: false,    # Disable update
  delete: false     # Disable delete
}
```

### Pagination

Configure pagination behavior:

```ruby
pagination: {
  enabled: true,        # Enable/disable pagination
  page_size: 25,        # Default page size
  max_page_size: 100,   # Maximum allowed page size
  total_count: true     # Include total count in response
}

# Disable pagination
pagination: { enabled: false }
```

### Filters

Define available filters for the index action:

```ruby
filters: [
  { name: :status, type: :string },
  { name: :created_after, type: :date },
  { name: :category_id, type: :integer }
]
```

### Relationships

Configure model associations to include:

```ruby
relationships: [
  { name: :author, type: :belongs_to },
  { name: :comments, type: :has_many },
  { name: :tags, type: :has_and_belongs_to_many }
]
```

## API Usage

Once configured, your API playground will be available at the configured routes:

### List Records
```bash
GET /api/playground/recipes
GET /api/playground/recipes?page[number]=2&page[size]=10
```

### Show Record
```bash
GET /api/playground/recipes/1
```

### Create Record
```bash
POST /api/playground/recipes
Content-Type: application/json

{
  "data": {
    "type": "recipes",
    "attributes": {
      "title": "Spaghetti Carbonara",
      "body": "Classic Italian pasta dish"
    }
  }
}
```

### Update Record
```bash
PATCH /api/playground/recipes/1
Content-Type: application/json

{
  "data": {
    "type": "recipes",
    "attributes": {
      "title": "Updated Spaghetti Carbonara"
    }
  }
}
```

### Delete Record
```bash
DELETE /api/playground/recipes/1
```

## JSON:API Compliance

All responses follow the [JSON:API specification](https://jsonapi.org/):

### Success Response
```json
{
  "data": {
    "id": "1",
    "type": "recipes",
    "attributes": {
      "title": "Spaghetti Carbonara",
      "body": "Classic Italian pasta dish"
    }
  },
  "meta": {
    "available_attributes": {
      "ungrouped": ["title", "body"]
    },
    "available_models": ["recipe"]
  }
}
```

### Error Response
```json
{
  "errors": [
    {
      "status": "422",
      "title": "Validation Error",
      "detail": "Title can't be blank",
      "source": {
        "pointer": "/data/attributes/title"
      }
    }
  ]
}
```

## Advanced Configuration

### Multiple Controllers

You can create multiple playground controllers with different configurations:

```ruby
# app/controllers/api/admin_playground_controller.rb
module Api
  class AdminPlaygroundController < ApplicationController
    include ApiPlayground

    # Admin-specific configuration with more permissions
    playground_for :user,
                  attributes: [:name, :email, :admin, :created_at],
                  requests: {
                    create: { fields: [:name, :email, :admin] },
                    update: { fields: [:name, :email, :admin] },
                    delete: true
                  }
  end
end

# app/controllers/api/public_playground_controller.rb
module Api
  class PublicPlaygroundController < ApplicationController
    include ApiPlayground

    # Public configuration with limited access
    playground_for :recipe,
                  attributes: [:title, :body],
                  requests: {
                    create: false,
                    update: false,
                    delete: false
                  }
  end
end
```

### Custom Authentication

Add authentication to your playground controllers:

```ruby
module Api
  class PlaygroundController < ApplicationController
    include ApiPlayground
    
    before_action :authenticate_user!
    before_action :ensure_admin!

    playground_for :recipe, attributes: [:title, :body]

    private

    def ensure_admin!
      head :forbidden unless current_user&.admin?
    end
  end
end
```

## API Key Protection

API Playground includes built-in API key protection to secure your playground endpoints. This feature allows you to require valid API keys for accessing your playground controllers.

### Configuration

Configure API key protection in an initializer:

```ruby
# config/initializers/api_playground.rb
ApiPlayground.configure do |config|
  config.api_key_model = 'ApiPlayground::ApiKey'  # Model to use for API keys
  config.api_key_field = 'token'                  # Field that stores the API key
  config.api_key_header = 'X-API-Key'            # Header to check for API key
end
```

### Database Setup

Generate and run the migration for API keys:

```bash
rails generate api_playground:install
rails db:migrate
```

This creates the `api_playground_api_keys` table with the following structure:
- `token` - The API key token (automatically generated)
- `expires_at` - Expiration timestamp
- `last_used_at` - Last usage timestamp (updated on each valid request)

### Protecting Controllers

Include the protection in your playground controllers:

```ruby
module Api
  class PlaygroundController < ApplicationController
    include ApiPlayground
    include ApiPlayground::ApiKeyProtection
    
    # Enable protection for all actions
    protected_playground!

    playground_for :recipe, attributes: [:title, :body]
  end
end
```

### Protection Modes

#### 1. Enable for All Actions

```ruby
class Api::PlaygroundController < ApplicationController
  include ApiPlayground
  include ApiPlayground::ApiKeyProtection
  protected_playground!  # All actions require API key
end
```

#### 2. Dynamic Protection Control

```ruby
class Api::PlaygroundController < ApplicationController
  include ApiPlayground
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

#### 3. Conditional Protection

```ruby
class Api::PlaygroundController < ApplicationController
  include ApiPlayground
  include ApiPlayground::ApiKeyProtection
  
  before_action :check_protection_needed
  
  private
  
  def check_protection_needed
    if Rails.env.production? || params[:require_auth] == 'true'
      self.class.protected_playground!
    else
      self.class.unprotected_playground!
    end
  end
end
```

### API Key Management with Rake Tasks

API Playground provides convenient rake tasks for managing API keys:

#### Create a New API Key

```bash
# Create an API key that expires in 5 days (default)
rails api_playground:key:create

# Create an API key with custom expiration
EXPIRY_DAYS=30 rails api_playground:key:create
```

Output:
```
API Key created successfully!
------------------------
Token: 2Kj8mN9pQrStUvWxYz3A4B5C
Expires at: 2024-01-15 10:30:00 UTC
------------------------
```

#### List All Valid API Keys

```bash
rails api_playground:key:list
```

Output:
```
Valid API Keys:
------------------------
Token: 2Kj8mN9pQrStUvWxYz3A4B5C
Expires at: 2024-01-15 10:30:00 UTC
Last used: 2024-01-10 14:22:33 UTC
------------------------
Token: 7Fg2hJ4kLmNpQrStUvWx8Y9Z
Expires at: 2024-01-20 09:15:00 UTC
Last used: Never
------------------------
```

#### Revoke an API Key

```bash
# Revoke a specific API key by token
rails api_playground:key:revoke[2Kj8mN9pQrStUvWxYz3A4B5C]
```

Output:
```
API key revoked successfully!
```

#### Clean Up Expired Keys

```bash
# Remove all expired API keys from the database
rails api_playground:key:cleanup
```

Output:
```
Removed 3 expired API key(s).
```

### Programmatic API Key Management

You can also manage API keys programmatically:

```ruby
# Create a new API key
api_key = ApiPlayground::ApiKey.create!(expires_at: 1.year.from_now)
puts api_key.token

# Find and validate an API key
key = ApiPlayground::ApiKey.find_by(token: 'your-token-here')
if key && !key.expired?
  puts "Valid key, last used: #{key.last_used_at}"
else
  puts "Invalid or expired key"
end

# Check if a token is valid (class method)
if ApiPlayground::ApiKey.valid_token?('your-token-here')
  puts "Token is valid"
end

# Get all valid (non-expired) keys
valid_keys = ApiPlayground::ApiKey.valid

# Manually expire a key
api_key.update!(expires_at: Time.current)
```

### Using API Keys in Requests

When protection is enabled, clients must include the API key in the request header:

```bash
# Example API requests with authentication
curl -H "X-API-Key: 2Kj8mN9pQrStUvWxYz3A4B5C" \
     -H "Content-Type: application/json" \
     http://localhost:3000/api/playground/recipes

# Create a new record
curl -X POST \
     -H "X-API-Key: 2Kj8mN9pQrStUvWxYz3A4B5C" \
     -H "Content-Type: application/json" \
     -d '{"data":{"type":"recipes","attributes":{"title":"New Recipe","body":"Recipe content"}}}' \
     http://localhost:3000/api/playground/recipes
```

### Error Responses

When API key validation fails, the API returns a 401 Unauthorized response:

```json
{
  "error": "Invalid or missing API key"
}
```

### Security Best Practices

1. **Use HTTPS**: Always use HTTPS in production to protect API keys in transit
2. **Regular Rotation**: Regularly rotate API keys using the rake tasks
3. **Monitor Usage**: Check `last_used_at` timestamps to identify unused keys
4. **Clean Up**: Regularly run the cleanup task to remove expired keys
5. **Environment-Specific**: Use different keys for different environments

```ruby
# Example: Environment-specific protection
class Api::PlaygroundController < ApplicationController
  include ApiPlayground
  include ApiPlayground::ApiKeyProtection
  
  # Only require API keys in production
  protected_playground! if Rails.env.production?
end
```

### Custom API Key Models

You can use your own API key model by configuring it:

```ruby
# config/initializers/api_playground.rb
ApiPlayground.configure do |config|
  config.api_key_model = 'MyCustomApiKey'
  config.api_key_field = 'access_token'
  config.api_key_header = 'Authorization'
end
```

Your custom model should implement:
- A scope called `valid` that returns non-expired keys
- A method called `touch_last_used` that updates the last used timestamp

```ruby
class MyCustomApiKey < ApplicationRecord
  scope :valid, -> { where('expires_at > ?', Time.current) }
  
  def touch_last_used
    update_column(:last_used_at, Time.current)
  end
end
```

## Testing

The gem includes comprehensive test coverage. To run tests in your application:

```bash
# Run all playground tests
bundle exec rspec spec/requests/api_playground/

# Run specific action tests
bundle exec rspec spec/requests/api_playground/create_spec.rb
bundle exec rspec spec/requests/api_playground/index_spec.rb
bundle exec rspec spec/requests/api_playground/show_spec.rb
bundle exec rspec spec/requests/api_playground/update_spec.rb
bundle exec rspec spec/requests/api_playground/delete_spec.rb
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for collaboration.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).