class TeachSession < ApplicationRecord
  # Crockford base32 minus 0/O/1/I/L/U — no glyph a teacher can misread
  # across a classroom, no accidental profanity vowels.
  PAIRING_CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTVWXYZ".freeze
  PAIRING_CODE_LENGTH = 6

  # Code expiry is encoded into expires_at: an unpaired session lives only as
  # long as its code (CODE_TTL); pairing extends it to the teaching window.
  CODE_TTL = 3.minutes
  SESSION_TTL = 12.hours

  belongs_to :lesson, optional: true  # null until paired
  belongs_to :teacher, class_name: "User", optional: true

  validates :current_page, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :expires_at, presence: true

  # App time, not SQL now() — expiry must follow the clock the rest of the
  # app (and travel-based tests) sees.
  scope :claimable, -> {
    where(lesson_id: nil).where(expires_at: Time.current..).where.not(pairing_code: nil)
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

  # A fresh unpaired session for a board's waiting screen.
  def self.issue!
    create!(pairing_code: generate_pairing_code, expires_at: CODE_TTL.from_now)
  end

  # The alphabet already excludes 0/O/1/I/L/U, so Crockford's O→0 / I,L→1
  # decode maps have nothing to map onto — normalization is upcase plus
  # stripping the "K7Q M2X" display grouping.
  def self.normalize_pairing_code(raw)
    raw.to_s.upcase.gsub(/[\s-]/, "")
  end

  # Single-use redeem, atomic against a concurrent redeem of the same code:
  # the guarded update_all matches zero rows the second time because pairing
  # nulls the code and sets lesson_id. Returns false if the code was lost.
  def claim!(lesson:, teacher:)
    now = Time.current
    claimed = self.class.claimable.where(id: id).update_all(
      pairing_code: nil,
      lesson_id: lesson.id,
      teacher_id: teacher.id,
      paired_at: now,
      last_seen_at: now,
      expires_at: now + SESSION_TTL,
      updated_at: now
    )
    claimed == 1 && reload
  end

  def paired? = paired_at.present?

  def started? = started_at.present?

  def expired? = expires_at <= Time.current

  # Paired but the teacher hasn't tapped Start — board shows the holding
  # screen (wordmark), never slide 1.
  def holding? = paired? && started_at.nil?

  def ended? = ended_at.present?
end
