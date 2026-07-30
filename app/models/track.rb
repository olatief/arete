class Track < ApplicationRecord
  SLUGS = %w[mizan arete ihsan].freeze

  has_many :units, -> { order(:grade, :position) }, dependent: :destroy, inverse_of: :track

  validates :slug, presence: true, uniqueness: true, inclusion: { in: SLUGS }
  validates :name, presence: true
  validates :position, presence: true
end
