# Idempotent seeds. The one super_admin comes from ENV so no credentials are
# committed; set SUPER_ADMIN_EMAIL and SUPER_ADMIN_PASSWORD before seeding.
email = ENV["SUPER_ADMIN_EMAIL"]
password = ENV["SUPER_ADMIN_PASSWORD"]

if email.present? && password.present?
  user = User.find_or_initialize_by(email_address: email)
  user.role = :super_admin
  user.password = password
  user.save!
  puts "Seeded super_admin #{user.email_address}"
else
  puts "Skipping super_admin seed — set SUPER_ADMIN_EMAIL and SUPER_ADMIN_PASSWORD."
end
