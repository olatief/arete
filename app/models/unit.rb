class Unit < ApplicationRecord
  belongs_to :track

  has_many :lessons, -> { order(:position) }, dependent: :destroy, inverse_of: :unit

  validates :grade, presence: true,
    numericality: { only_integer: true, in: 0..12 } # K = 0
  validates :title, presence: true
  validates :position, presence: true
end
