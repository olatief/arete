class Slide < ApplicationRecord
  belongs_to :lesson

  # :preview is the companion phone's thumbnail. preprocessed: true generates
  # it in a background job at attach time, so companion requests never run
  # vips in a web worker — they just redirect to the stored variant.
  has_one_attached :image do |attachable|
    attachable.variant :preview, resize_to_limit: [ 480, 270 ], preprocessed: true
  end

  # page_number IS the ordering — no position column, no reordering.
  validates :page_number, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 1 },
    uniqueness: { scope: :lesson_id }

  validates :suggested_seconds,
    numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
