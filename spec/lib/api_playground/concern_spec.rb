# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApiPlayground do
  # Create a test controller that includes the concern
  let(:controller_class) do
    Class.new(ActionController::Base) do
      include ApiPlayground
    end
  end

  let(:controller) { controller_class.new }

  describe '.playground_for' do
    context 'with basic attributes' do
      before do
        controller_class.playground_for :recipe, attributes: [:title, :body]
      end

      it 'configures basic attributes correctly' do
        config = controller_class.playground_configurations['recipe']
        expect(config[:attributes][:ungrouped]).to contain_exactly(:title, :body)
      end
    end

    context 'with grouped attributes' do
      before do
        controller_class.playground_for :recipe,
          attributes: [
            :title,
            { timestamps: [:created_at, :updated_at] },
            { metrics: [:views_count] }
          ]
      end

      it 'configures grouped attributes correctly' do
        config = controller_class.playground_configurations['recipe']
        expect(config[:attributes][:ungrouped]).to contain_exactly(:title)
        expect(config[:attributes][:timestamps]).to contain_exactly(:created_at, :updated_at)
        expect(config[:attributes][:metrics]).to contain_exactly(:views_count)
      end
    end

    context 'with relationships' do
      before do
        controller_class.playground_for :recipe,
          attributes: [:title],
          relationships: [:author, :categories]
      end

      it 'configures relationships correctly' do
        config = controller_class.playground_configurations['recipe']
        expect(config[:relationships]).to contain_exactly(:author, :categories)
      end
    end

    context 'with filters' do
      before do
        controller_class.playground_for :recipe,
          attributes: [:title],
          filters: [
            { field: 'title', type: :exact },
            { field: 'summary', type: :partial }
          ]
      end

      it 'normalizes filters correctly' do
        config = controller_class.playground_configurations['recipe']
        expect(config[:filters]).to contain_exactly(
          { field: 'title', type: :exact },
          { field: 'summary', type: :partial }
        )
      end
    end

    context 'with pagination' do
      context 'with custom settings' do
        before do
          controller_class.playground_for :recipe,
            attributes: [:title],
            pagination: {
              enabled: false,
              page_size: 30,
              total_count: false
            }
        end

        it 'configures pagination settings correctly' do
          config = controller_class.playground_configurations['recipe']
          expect(config[:pagination]).to include(
            enabled: false,
            page_size: 30,
            total_count: false
          )
        end
      end

      context 'with default settings' do
        before do
          controller_class.playground_for :recipe, attributes: [:title]
        end

        it 'uses default pagination settings' do
          config = controller_class.playground_configurations['recipe']
          expect(config[:pagination]).to include(
            enabled: true,
            page_size: 15,
            total_count: true
          )
        end
      end

      context 'with invalid page size' do
        before do
          controller_class.playground_for :recipe,
            attributes: [:title],
            pagination: { page_size: 100 }
        end

        it 'caps page size at maximum allowed value' do
          config = controller_class.playground_configurations['recipe']
          expect(config[:pagination][:page_size]).to eq(50)
        end
      end
    end
  end

  describe 'request handling' do
    let(:recipe_class) do
      Class.new do
        include ActiveModel::Model
        include ActiveModel::Attributes
        
        attribute :id, :integer
        attribute :title, :string
        attribute :body, :string
        attribute :created_at, :datetime
        attribute :updated_at, :datetime
        
        def self.model_name
          ActiveModel::Name.new(self, nil, "Recipe")
        end

        # Add class methods for ActiveRecord-like behavior
        class << self
          def find(id)
            raise ActiveRecord::RecordNotFound unless id == '1'
            new(id: 1)
          end

          def all
            []
          end

          def where(conditions)
            all
          end
        end
      end
    end

    before do
      stub_const('Recipe', recipe_class)
      stub_const('ActiveRecord::RecordNotFound', Class.new(StandardError))
      
      controller_class.playground_for :recipe,
        attributes: [
          :title,
          :body,
          { timestamps: [:created_at, :updated_at] }
        ],
        filters: [
          { field: 'title', type: :partial }
        ],
        pagination: { page_size: 10 }

      allow(controller).to receive(:params).and_return(
        ActionController::Parameters.new(
          model_name: 'recipe',
          id: '1'
        )
      )
    end

    describe '#discover' do
      context 'when model exists' do
        let(:recipe) do
          Recipe.new(
            id: 1,
            title: 'Test Recipe',
            body: 'Test Body',
            created_at: Time.current,
            updated_at: Time.current
          )
        end

        before do
          allow(Recipe).to receive(:find).with('1').and_return(recipe)
        end

        it 'returns serialized resource' do
          allow(controller).to receive(:render)
          controller.discover
          
          expect(controller).to have_received(:render).with(
            hash_including(
              json: hash_including(
                data: hash_including(
                  id: '1',
                  type: 'recipes',
                  attributes: hash_including(
                    title: 'Test Recipe',
                    body: 'Test Body'
                  )
                )
              )
            )
          )
        end
      end

      context 'when model does not exist' do
        before do
          allow(controller).to receive(:params).and_return(
            ActionController::Parameters.new(model_name: 'invalid')
          )
        end

        it 'returns model not found error' do
          allow(controller).to receive(:render)
          controller.discover
          
          expect(controller).to have_received(:render).with(
            hash_including(
              json: hash_including(
                errors: array_including(
                  hash_including(
                    status: '404',
                    title: 'Model not found',
                    detail: "The requested model 'invalid' is not available in the playground",
                    available_models: ['recipe']
                  )
                )
              ),
              status: :not_found
            )
          )
        end
      end
    end

    describe '#format_attribute_value' do
      it 'formats Time objects as ISO8601' do
        time = Time.current
        expect(controller.send(:format_attribute_value, time)).to eq(time.iso8601)
      end

      it 'formats Date objects as ISO8601' do
        date = Date.current
        expect(controller.send(:format_attribute_value, date)).to eq(date.iso8601)
      end

      it 'returns other values as is' do
        expect(controller.send(:format_attribute_value, 'test')).to eq('test')
        expect(controller.send(:format_attribute_value, 123)).to eq(123)
      end
    end

    describe '#serialize_errors' do
      let(:resource) do
        recipe = Recipe.new
        recipe.errors.add(:title, "can't be blank")
        recipe
      end

      it 'formats errors according to JSONAPI spec' do
        errors = controller.send(:serialize_errors, resource)
        expect(errors).to contain_exactly(
          hash_including(
            status: '422',
            title: 'Validation Error',
            detail: "Title can't be blank",
            source: { pointer: '/data/attributes/title' }
          )
        )
      end
    end
  end
end 