# Deletes only expired, never-paired sessions (abandoned boards' pairing
# stubs). Paired rows are retained as teaching history — they are the data
# source for "My lessons" (TeachSession.taught). Teacher-only behavioural
# data; no student anything.
class TeachSessionSweepJob < ApplicationJob
  queue_as :default

  def perform
    TeachSession.where(paired_at: nil).where(expires_at: ...Time.current).delete_all
  end
end
