module ApiPlayground
  class ApiKey < ActiveRecord::Base
    validates :token, presence: true, uniqueness: { case_sensitive: true }, on: :update
    validates :token, uniqueness: { case_sensitive: true }, on: :create
    validates :expires_at, presence: true, unless: -> { new_record? && expires_at.nil? && !validation_context }

    scope :valid, -> { where('expires_at > ?', Time.current) }

    before_create :generate_token
    before_validation :ensure_expires_at, on: :create

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
      return if token.present?

      max_attempts = 10
      attempts = 0
      
      begin
        attempts += 1
        self.token = SecureRandom.base58(24)
        
        # Try to find any existing records with this token
        if self.class.exists?(token: token)
          if attempts >= max_attempts
            errors.add(:token, "could not generate a unique token after #{max_attempts} attempts")
            raise ActiveRecord::RecordInvalid.new(self)
          end
          next
        end
        
        break # Token is unique, we can use it
      end while attempts < max_attempts
    end

    def ensure_expires_at
      return if expires_at.present?
      self.expires_at = 5.days.from_now
    end
  end
end 