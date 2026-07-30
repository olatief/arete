class CreateSlides < ActiveRecord::Migration[8.1]
  def change
    create_table :slides do |t|
      t.references :lesson, null: false, foreign_key: true
      t.integer :page_number, null: false # 1-based; IS the ordering
      t.string  :title                    # shown on companion + print; nullable
      t.integer :suggested_seconds        # per-slide pacing target; nullable
      t.text    :notes                    # private teacher script
      t.timestamps
      t.index [ :lesson_id, :page_number ], unique: true
    end
  end
end
