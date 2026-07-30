# Idempotent seeds — safe to re-run; a second `db:seed` is a no-op.

# The one super_admin comes from ENV so no credentials are committed;
# set SUPER_ADMIN_EMAIL and SUPER_ADMIN_PASSWORD before seeding.
email = ENV["SUPER_ADMIN_EMAIL"]
password = ENV["SUPER_ADMIN_PASSWORD"]

if email.present? && password.present?
  user = User.find_or_initialize_by(email_address: email)
  user.role = :super_admin
  user.password = password
  user.save! if user.changed?
  puts "Seeded super_admin #{user.email_address}"
else
  puts "Skipping super_admin seed — set SUPER_ADMIN_EMAIL and SUPER_ADMIN_PASSWORD."
end

# Content: the real Arête K–12 tree, then the fully-worked Kindness fixture.
require_relative "seeds/arete_tree"
require_relative "seeds/kindness_lesson"

# One school and one teacher for development sign-in. Never in production.
unless Rails.env.production?
  school = School.find_or_create_by!(name: "Mīzān Demo School") do |s|
    s.country = "EG"
    s.timezone = "Africa/Cairo"
  end

  teacher = User.find_or_initialize_by(email_address: "teacher@example.com")
  if teacher.new_record?
    teacher.school = school
    teacher.role = :teacher
    teacher.password = "password"
    teacher.save!
  end
  puts "Seeded dev teacher teacher@example.com / password (#{school.name})"
end
