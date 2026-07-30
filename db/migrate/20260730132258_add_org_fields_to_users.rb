class AddOrgFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    # Nullable on purpose: super_admins belong to no school.
    add_reference :users, :school, null: true, foreign_key: true
    add_column :users, :role, :string, null: false, default: "teacher"
    add_column :users, :ui_locale, :string, null: false, default: "en"
  end
end
