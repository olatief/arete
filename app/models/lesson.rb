class Lesson < ApplicationRecord
  LOCALES = %w[en ar].freeze

  belongs_to :unit

  has_many :slides, -> { order(:page_number) }, dependent: :destroy, inverse_of: :lesson
  has_many :teach_sessions, dependent: :nullify

  has_one_attached :deck
  has_many_attached :materials

  validates :code, presence: true, uniqueness: { scope: :locale }
  validates :locale, presence: true, inclusion: { in: LOCALES }
  validates :title, presence: true
  validates :position, presence: true

  scope :published, -> { where.not(published_at: nil) }
  # Full-text search scaffold (M2). ~260 lessons — no search gem, no tsvector column.
  scope :search, ->(q) {
    where("to_tsvector('english', coalesce(title,'') || ' ' || coalesce(prime,'')) @@ websearch_to_tsquery('english', ?)", q)
  }

  def published? = published_at.present?
end
