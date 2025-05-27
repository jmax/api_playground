module Api
  class TestPlaygroundController < ApplicationController
    include ApiPlayground

    # Configuration with multiple features disabled for testing
    playground_for :recipe,
                  attributes: [:title, :body],
                  pagination: { enabled: false, page_size: 15, total_count: false },
                  requests: {
                    create: false,
                    update: false,
                    delete: true
                  }
  end
end 