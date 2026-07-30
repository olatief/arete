class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :school, optional: true # super_admins have none

  enum :role, { teacher: "teacher", school_admin: "school_admin", super_admin: "super_admin" }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
