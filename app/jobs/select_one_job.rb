# M0 smoke job: proves Solid Queue executes inside Puma with only bin/dev
# running (no separate worker process).
class SelectOneJob < ApplicationJob
  queue_as :default

  def perform
    result = ActiveRecord::Base.connection.select_value("SELECT 1")
    Rails.logger.info "SelectOneJob executed: SELECT 1 => #{result.inspect}"
  end
end
