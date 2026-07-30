class CreateTracks < ActiveRecord::Migration[8.1]
  def change
    create_table :tracks do |t|
      t.string  :slug, null: false # mizan | arete | ihsan
      t.string  :name, null: false
      t.integer :position, null: false
      t.timestamps
      t.index :slug, unique: true
    end
  end
end
