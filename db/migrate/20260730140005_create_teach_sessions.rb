class CreateTeachSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :teach_sessions do |t|
      t.references :lesson, null: true, foreign_key: true # null until paired
      t.references :teacher, null: true, foreign_key: { to_table: :users }
      t.string   :pairing_code # nulled on pair — single use
      t.integer  :current_page, null: false, default: 1
      t.datetime :paired_at
      t.datetime :started_at # nil until teacher taps Start (board holds)
      t.datetime :ended_at   # nil until End; retained rows = teaching history
      t.datetime :expires_at, null: false
      t.datetime :last_seen_at
      t.timestamps
      t.index :pairing_code, unique: true, where: "pairing_code IS NOT NULL"
      t.index [ :teacher_id, :last_seen_at ] # powers "My lessons" recents
    end
  end
end
