class CreateLessons < ActiveRecord::Migration[8.1]
  def change
    create_table :lessons do |t|
      t.references :unit, null: false, foreign_key: true
      t.integer  :position, null: false
      t.string   :code, null: false
      t.string   :locale, null: false, default: "en" # en | ar
      t.string   :title, null: false
      t.text     :prime                              # read-before-you-teach brief
      t.text     :close_prompt                       # exit question
      t.integer  :estimated_minutes
      t.text     :tags, array: true, default: [], null: false
      t.datetime :published_at                       # nil = draft
      t.timestamps
      t.index [ :code, :locale ], unique: true
      t.index :tags, using: :gin
    end
  end
end
