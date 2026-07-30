class TeachSession < ApplicationRecord
  # Crockford base32 minus 0/O/1/I/L/U — no glyph a teacher can misread
  # across a classroom, no accidental profanity vowels.
  PAIRING_CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTVWXYZ".freeze
  PAIRING_CODE_LENGTH = 6

  belongs_to :lesson, optional: true  # null until paired
  belongs_to :teacher, class_name: "User", optional: true

  validates :current_page, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :expires_at, presence: true

  scope :claimable, -> {
    where(lesson_id: nil).where("expires_at > now()").where.not(pairing_code: nil)
  }

  # Paired rows are retained as teaching history (powers "My lessons");
  # the sweep job deletes only expired never-paired sessions.
  scope :taught, -> { where.not(paired_at: nil) }

  def self.generate_pairing_code
    Array.new(PAIRING_CODE_LENGTH) {
      PAIRING_CODE_ALPHABET[SecureRandom.random_number(PAIRING_CODE_ALPHABET.length)]
    }.join
  end

  def generate_pairing_code
    self.pairing_code = self.class.generate_pairing_code
  end

  def paired? = paired_at.present?

  def expired? = expires_at <= Time.current

  # Paired but the teacher hasn't tapped Start — board shows the holding
  # screen (wordmark), never slide 1.
  def holding? = paired? && started_at.nil?

  def ended? = ended_at.present?
end
