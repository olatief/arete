class Slide < ApplicationRecord
  belongs_to :lesson

  has_one_attached :image

  # page_number IS the ordering — no position column, no reordering.
  validates :page_number, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 1 },
    uniqueness: { scope: :lesson_id }

  validates :suggested_seconds,
    numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
