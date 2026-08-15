require "test_helper"

class TeachSessionChannelTest < ActionCable::Channel::TestCase
  setup do
    @teach_session = TeachSession.issue!
    stub_connection current_user: nil # the board subscribes with no user
  end

  test "subscribes with a valid signed token and streams for the session" do
    subscribe token: @teach_session.signed_id(purpose: :board_stream, expires_in: 12.hours)

    assert subscription.confirmed?
    assert_has_stream_for @teach_session
  end

  # Test 5: a guessed stream is rejected — subscription auth is the signed
  # token, never a param-built stream name.
  test "rejects a forged token" do
    subscribe token: "forged-nonsense"
    assert subscription.rejected?
  end

  test "rejects a missing token" do
    subscribe
    assert subscription.rejected?
  end

  test "rejects a raw integer id in place of a token" do
    subscribe token: @teach_session.id.to_s
    assert subscription.rejected?
  end

  test "rejects a signed id minted for a different purpose" do
    subscribe token: @teach_session.signed_id(purpose: :something_else, expires_in: 12.hours)
    assert subscription.rejected?
  end

  # The signed id authenticates but is not revocable — the live expires_at
  # check is what ends a stream's life.
  test "rejects a valid token once the session has expired" do
    token = @teach_session.signed_id(purpose: :board_stream, expires_in: 12.hours)
    @teach_session.update!(expires_at: 1.minute.ago)

    subscribe token: token
    assert subscription.rejected?
  end
end
