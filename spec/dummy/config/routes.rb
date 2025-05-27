Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  # API Playground routes
  namespace :api do
    scope :playground do
      get ':model_name', to: 'playground#discover'
      get ':model_name/:id', to: 'playground#discover'
      post ':model_name', to: 'playground#create'
      patch ':model_name/:id', to: 'playground#update'
      delete ':model_name/:id', to: 'playground#destroy'
    end
  end
end
