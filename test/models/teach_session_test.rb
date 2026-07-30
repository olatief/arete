require "test_helper"

class TeachSessionTest < ActiveSupport::TestCase
  test "pairing codes use only the Crockford alphabet — no 0 O 1 I L U" do
    200.times do
      code = TeachSession.generate_pairing_code
      assert_equal 6, code.length
      assert_match(/\A[#{TeachSession::PAIRING_CODE_ALPHABET}]{6}\z/, code)
      assert_no_match(/[0O1ILU]/, code)
    end
  end

  test "pairing_code uniqueness is enforced by a partial index" do
    TeachSession.create!(pairing_code: "ABCDEF", expires_at: 5.minutes.from_now)
    dup = TeachSession.new(pairing_code: "ABCDEF", expires_at: 5.minutes.from_now)
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "many paired sessions may all have a null pairing_code" do
    2.times { TeachSession.create!(pairing_code: nil, expires_at: 5.minutes.from_now) }
    assert_operator TeachSession.where(pairing_code: nil).count, :>=, 2
  end

  test "claimable returns only unclaimed, unexpired sessions that still hold a code" do
    claimable = TeachSession.create!(pairing_code: "AAAAAA", expires_at: 5.minutes.from_now)
    expired   = TeachSession.create!(pairing_code: "BBBBBB", expires_at: 1.minute.ago)
    redeemed  = TeachSession.create!(pairing_code: nil, expires_at: 5.minutes.from_now)
    paired    = TeachSession.create!(
      pairing_code: "CCCCCC", expires_at: 5.minutes.from_now,
      lesson: build_kindness_lesson, paired_at: Time.current
    )

    assert_includes TeachSession.claimable, claimable
    assert_not_includes TeachSession.claimable, expired
    assert_not_includes TeachSession.claimable, redeemed
    assert_not_includes TeachSession.claimable, paired
  end

  test "paired? and expired?" do
    session = TeachSession.new(expires_at: 1.minute.ago)
    assert session.expired?
    assert_not session.paired?

    session.expires_at = 5.minutes.from_now
    session.paired_at = Time.current
    assert_not session.expired?
    assert session.paired?
  end

  test "generate_pairing_code assigns a code to the instance" do
    session = TeachSession.new(expires_at: 5.minutes.from_now)
    session.generate_pairing_code
    assert_match(/\A[#{TeachSession::PAIRING_CODE_ALPHABET}]{6}\z/, session.pairing_code)
  end

  test "current_page defaults to 1" do
    session = TeachSession.create!(expires_at: 5.minutes.from_now)
    assert_equal 1, session.reload.current_page
  end

  test "taught returns only sessions that were ever paired" do
    never_paired = TeachSession.create!(pairing_code: "DDDDDD", expires_at: 1.minute.ago)
    taught = TeachSession.create!(
      pairing_code: nil, expires_at: 5.minutes.from_now,
      lesson: build_kindness_lesson, paired_at: Time.current
    )

    assert_includes TeachSession.taught, taught
    assert_not_includes TeachSession.taught, never_paired
  end

  test "holding? and ended?" do
    session = TeachSession.new(expires_at: 5.minutes.from_now)
    assert_not session.holding? # never paired — still waiting, not holding

    session.paired_at = Time.current
    assert session.holding?
    assert_not session.ended?

    session.started_at = Time.current
    assert_not session.holding?

    session.ended_at = Time.current
    assert session.ended?
  end
end
