FactoryBot.define do
  factory :api_key, class: 'ApiPlayground::ApiKey' do
    expires_at { 5.days.from_now }
    
    # For persisted records, we need a token
    after(:build) do |api_key|
      api_key.token = SecureRandom.base58(24) if api_key.persisted?
    end
    
    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :valid do
      expires_at { 5.days.from_now }
    end

    # For when we need to explicitly set a token
    trait :with_token do
      token { SecureRandom.base58(24) }
    end
  end
end 