class CreateUnits < ActiveRecord::Migration[8.1]
  def change
    create_table :units do |t|
      t.references :track, null: false, foreign_key: true
      t.integer :grade, null: false # K = 0
      t.string  :title, null: false
      t.integer :position, null: false
      t.timestamps
    end
  end
end
