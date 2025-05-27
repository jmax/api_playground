# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApiPlayground::ApiKey, type: :model do
  describe 'validations and callbacks' do
    describe 'expires_at' do
      it 'requires expires_at to be set when explicitly validating' do
        api_key = build(:api_key)
        api_key.expires_at = nil
        api_key.validate(context: :test) # Force validation without callbacks
        expect(api_key.errors[:expires_at]).to include("can't be blank")
      end

      it 'sets default expiration on create' do
        freeze_time do
          api_key = described_class.new
          api_key.valid?
          expect(api_key.expires_at).to eq(5.days.from_now)
        end
      end

      it 'requires expires_at when updating' do
        api_key = create(:api_key)
        api_key.expires_at = nil
        expect(api_key).not_to be_valid
        expect(api_key.errors[:expires_at]).to include("can't be blank")
      end
    end

    describe 'token' do
      context 'on create' do
        it 'does not require token to be present' do
          api_key = build(:api_key, token: nil)
          expect(api_key).to be_valid
        end

        it 'generates a token before create' do
          api_key = create(:api_key)
          expect(api_key.token).to be_present
        end

        it 'ensures token uniqueness' do
          existing_key = create(:api_key)
          new_key = build(:api_key, token: existing_key.token)
          
          expect(new_key).not_to be_valid
          expect(new_key.errors[:token]).to include('has already been taken')
        end
      end

      context 'on update' do
        let(:api_key) { create(:api_key) }

        it 'requires token to be present' do
          api_key.token = nil
          expect(api_key).not_to be_valid
          expect(api_key.errors[:token]).to include("can't be blank")
        end

        it 'ensures token uniqueness' do
          other_key = create(:api_key)
          api_key.token = other_key.token
          
          expect(api_key).not_to be_valid
          expect(api_key.errors[:token]).to include('has already been taken')
        end
      end
    end
  end

  describe 'scopes' do
    describe '.valid' do
      let!(:valid_key) { create(:api_key, expires_at: 1.day.from_now) }
      let!(:expired_key) { create(:api_key, expires_at: 1.day.ago) }

      it 'returns only valid keys' do
        expect(described_class.valid).to include(valid_key)
        expect(described_class.valid).not_to include(expired_key)
      end
    end
  end

  describe '.valid_token?' do
    context 'when token exists and is valid' do
      let!(:api_key) { create(:api_key, expires_at: 1.day.from_now) }

      it 'returns true' do
        expect(described_class.valid_token?(api_key.token)).to be true
      end
    end

    context 'when token exists but is expired' do
      let!(:api_key) { create(:api_key, expires_at: 1.day.ago) }

      it 'returns false' do
        expect(described_class.valid_token?(api_key.token)).to be false
      end
    end

    context 'when token does not exist' do
      it 'returns false' do
        expect(described_class.valid_token?('nonexistent')).to be false
      end
    end
  end

  describe '#expired?' do
    it 'returns true when expires_at is in the past' do
      api_key = build(:api_key, expires_at: 1.day.ago)
      expect(api_key).to be_expired
    end

    it 'returns false when expires_at is in the future' do
      api_key = build(:api_key, expires_at: 1.day.from_now)
      expect(api_key).not_to be_expired
    end
  end

  describe '#touch_last_used' do
    let(:api_key) { create(:api_key) }

    it 'updates last_used_at to current time' do
      freeze_time do
        expect { api_key.touch_last_used }
          .to change { api_key.reload.last_used_at }
          .to(Time.current)
      end
    end
  end

  describe 'token generation' do
    it 'generates unique tokens' do
      first_key = create(:api_key)
      second_key = create(:api_key)
      
      expect(second_key.token).not_to eq(first_key.token)
      expect(second_key.token).to be_present
    end

    it 'retries on duplicate tokens' do
      existing_key = create(:api_key)
      allow(SecureRandom).to receive(:base58).and_return(existing_key.token, 'new_unique_token')
      
      new_key = create(:api_key)
      expect(new_key.token).to eq('new_unique_token')
    end

    it 'raises RecordInvalid after max attempts' do
      existing_key = create(:api_key)
      allow(SecureRandom).to receive(:base58).and_return(existing_key.token)
      
      expect {
        create(:api_key)
      }.to raise_error(ActiveRecord::RecordInvalid) { |error|
        expect(error.record.errors[:token])
          .to include(/could not generate a unique token after \d+ attempts/)
      }
    end
  end
end 