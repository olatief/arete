class CreateSchools < ActiveRecord::Migration[8.1]
  def change
    create_table :schools do |t|
      t.string :name, null: false
      t.string :country
      t.string :timezone

      t.timestamps
    end
  end
end
