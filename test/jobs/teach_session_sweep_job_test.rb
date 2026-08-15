require "test_helper"

class TeachSessionSweepJobTest < ActiveJob::TestCase
  test "deletes only expired never-paired sessions" do
    abandoned = TeachSession.issue!
    abandoned.update!(expires_at: 1.minute.ago)

    waiting = TeachSession.issue!

    # Paired rows are teaching history — retained even when long expired.
    lesson = build_kindness_lesson
    taught = TeachSession.issue!
    assert taught.claim!(lesson: lesson, teacher: users(:one))
    taught.update!(ended_at: 2.days.ago, expires_at: 2.days.ago)

    TeachSessionSweepJob.perform_now

    assert_not TeachSession.exists?(abandoned.id)
    assert TeachSession.exists?(waiting.id)
    assert TeachSession.exists?(taught.id)
  end
end
