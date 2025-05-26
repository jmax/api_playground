Initial release: API Playground gem

Create standalone gem from Rails engine providing API playground functionality
with secure API key authentication and flexible model configuration.

Key Features:
- API key authentication with automatic token generation and expiration
- Configurable model endpoints with filtering and pagination
- Flexible attribute and relationship exposure
- Request whitelisting and validation
- Customizable filtering options
- Optional pagination with performance optimizations

Core Components:
- ApiPlayground::ApiKey model for key management
- ApiPlayground::ApiKeyProtection concern for controller security
- Install generator for easy setup
- Configuration system for customization
- Engine setup with proper namespacing and isolation

Technical Details:
- Secure token generation using SecureRandom.base58
- Automatic table name prefixing (api_playground_)
- Last used tracking for API keys
- Proper Rails engine isolation
- Configurable headers and model settings

Migration from Rails App:
- Moved and namespaced all components under ApiPlayground module
- Restructured files to follow gem conventions
- Added proper configuration options
- Enhanced documentation and examples
- Improved security with proper isolation

Documentation:
- Comprehensive README with installation instructions
- Configuration examples and best practices
- API key management guide
- Model playground setup examples
- Security considerations 