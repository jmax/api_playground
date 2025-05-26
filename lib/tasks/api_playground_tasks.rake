namespace :api_playground do
  namespace :key do
    desc 'Create a new API key'
    task create: :environment do
      expiry_days = ENV['EXPIRY_DAYS']&.to_i || 5
      api_key = ApiPlayground::ApiKey.create!(expires_at: expiry_days.days.from_now)
      
      puts "\nAPI Key created successfully!"
      puts "------------------------"
      puts "Token: #{api_key.token}"
      puts "Expires at: #{api_key.expires_at}"
      puts "------------------------"
    end

    desc 'List all valid API keys'
    task list: :environment do
      keys = ApiPlayground::ApiKey.valid.order(expires_at: :asc)
      
      if keys.any?
        puts "\nValid API Keys:"
        puts "------------------------"
        keys.each do |key|
          puts "Token: #{key.token}"
          puts "Expires at: #{key.expires_at}"
          puts "Last used: #{key.last_used_at || 'Never'}"
          puts "------------------------"
        end
      else
        puts "\nNo valid API keys found."
      end
    end

    desc 'Revoke an API key by setting its expiration to now'
    task :revoke, [:token] => :environment do |t, args|
      if args[:token].blank?
        puts "Error: Token is required"
        puts "Usage: rake api_playground:key:revoke[token]"
        next
      end

      api_key = ApiPlayground::ApiKey.find_by(token: args[:token])
      
      if api_key
        api_key.update!(expires_at: Time.current)
        puts "\nAPI key revoked successfully!"
      else
        puts "\nAPI key not found."
      end
    end

    desc 'Clean up expired API keys'
    task cleanup: :environment do
      count = ApiPlayground::ApiKey.where('expires_at <= ?', Time.current).delete_all
      puts "\nRemoved #{count} expired API key(s)."
    end
  end
end 