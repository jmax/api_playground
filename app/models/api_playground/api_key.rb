module ApiPlayground
  class ApiKey < ActiveRecord::Base
    validates :token, presence: true, uniqueness: true
    validates :expires_at, presence: true

    scope :valid, -> { where('expires_at > ?', Time.current) }

    before_validation :generate_token, on: :create
    before_validation :set_default_expiration, on: :create

    def self.valid_token?(token)
      valid.exists?(token: token)
    end

    def expired?
      expires_at <= Time.current
    end

    def touch_last_used
      update_column(:last_used_at, Time.current)
    end

    private

    def generate_token
      self.token = loop do
        random_token = SecureRandom.base58(24)
        break random_token unless self.class.exists?(token: random_token)
      end
    end

    def set_default_expiration
      self.expires_at ||= 5.days.from_now
    end
  end
end 