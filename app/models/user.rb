class User < ActiveRecord::Base
    attr_accessor :confirmation_token, :pin, :activation_token, :reset_token
    has_one :user_extra
    accepts_nested_attributes_for :user_extra
    mount_uploader :avatar, AvatarUploader
    before_create :create_confirmation_digest, if: :email
    before_save   :downcase_email, if: :email
    validates :name, presence:  { message: "用户名没填写" },
                    length: { maximum: 20,:too_long => '用户名最长20个字符' },
                    uniqueness: { message: "该用户名被使用" }
    VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
    validates :email, presence: { message: "邮箱地址没有填写" }, length: { maximum: 100,:too_long => '邮箱地址最长100个字符' },
                      format: { with: VALID_EMAIL_REGEX,message: "非法的邮箱地址"},
                      uniqueness: { case_sensitive: false,message: "该邮箱地址被使用" },
                      unless: :phone?
    validates :phone, phone: { types: :mobile ,message: "请使用中国大陆地区的手机号"}, uniqueness: {message: "该邮箱地址被使用"} , unless: :email?
    has_secure_password
    validates :password, presence: true, length: { minimum: 6 ,:too_short => '密码至少要6个字符'}, allow_nil: true,allow_blank:{message:"kkkkkkk"}
    validates_integrity_of  :avatar
    validates_processing_of :avatar
    validate :avatar_size_validation

    def reject_tour(attributes)
        exists = attributes['id'].present?
        empty = attributes.slice(:when, :where).values.all?(&:blank)
        attributes[:_destroy] = 1 if exists && empty # destroy empty tour
        (!exists && empty) # reject empty attributes
    end

    def password_reset_expired?
        reset_sent_at < 2.hours.ago
    end

    def confirmation_expired?
        confirmation_sent_at < 2.hours.ago
    end

    def authenticated?(confirmation_token)
        return false if confirmation_digest.nil?
        BCrypt::Password.new(confirmation_digest).is_password?(confirmation_token)
    end

    def authenticated_reset?(token)
        return false if reset_digest.nil?
        BCrypt::Password.new(reset_digest).is_password?(token)
    end

    def self.digest(string)
        cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
                                                      BCrypt::Engine.cost
        BCrypt::Password.create(string, cost: cost)
    end

    def self.new_token
        SecureRandom.urlsafe_base64
    end

    def downcase_email
        self.email = email.downcase
    end

    def create_reset_digest
        self.reset_token = User.new_token
        update_attribute(:reset_digest,  User.digest(reset_token))
        update_attribute(:reset_sent_at, Time.zone.now)
    end

    def create_new_email_digest
        self.confirmation_token = User.new_token
        update_attribute(:confirmation_digest, User.digest(confirmation_token))
        update_attribute(:confirmation_sent_at, Time.zone.now)
    end

    def send_password_reset_email
        @reset_token = self.reset_token
        UserMailer.password_reset(self,@reset_token).deliver_later
    end

    private

    def avatar_size_validation
        errors[:avatar] << 'should be less than 500KB' if avatar.size > 0.5.megabytes
    end

    def downcase_email
        self.email = email.downcase
    end

    def create_confirmation_digest
        self.confirmation_token = User.new_token
        self.confirmation_digest = User.digest(confirmation_token)
        self.confirmation_sent_at = Time.zone.now
    end
end
