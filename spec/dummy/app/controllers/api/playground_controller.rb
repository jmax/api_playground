module Api
  class PlaygroundController < ApplicationController
    include ApiPlayground
    include ApiPlayground::Documentation

    playground_for :recipe,
                  attributes: [:title, :body],
                  requests: {
                    create: { fields: [:title, :body] },
                    update: { fields: [:title, :body] },
                    delete: true
                  }
  end
end 