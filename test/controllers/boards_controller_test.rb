require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  test "GET /board issues a session with a code and a signed cookie" do
    assert_difference "TeachSession.count", 1 do
      get board_path
    end

    assert_response :success
    teach_session = TeachSession.last
    assert_equal 6, teach_session.pairing_code.length
    assert_nil teach_session.paired_at
    # Rendered grouped for across-the-room legibility.
    assert_includes response.body, teach_session.pairing_code.scan(/.{1,3}/).join(" ")
  end

  test "refreshing an unpaired unexpired board is idempotent" do
    get board_path
    teach_session = TeachSession.last

    assert_no_difference "TeachSession.count" do
      get board_path
    end
    assert_includes response.body, teach_session.pairing_code.scan(/.{1,3}/).join(" ")
  end

  test "an expired code gets a fresh session on refresh" do
    get board_path
    first = TeachSession.last

    travel 5.minutes do
      assert_difference "TeachSession.count", 1 do
        get board_path
      end
    end
    assert_not_equal first.id, TeachSession.last.id
  end

  test "an ended session gets a fresh session and code on refresh" do
    teach_session = pair_board_session
    teach_session.update!(ended_at: Time.current, expires_at: Time.current)

    assert_difference "TeachSession.count", 1 do
      get board_path
    end
    assert_response :success
    assert_not_nil TeachSession.last.pairing_code
  end

  test "a paired board preloads every slide image with the holding screen up" do
    pair_board_session(attach_files: true)

    get board_path
    assert_response :success
    assert_equal 8, response.body.scan("slide-layer").size
    assert_not_includes response.body, "slide-layer is-active" # holding, not slide 1
  end

  # Test 9 (server half): a board that reconnects during pre-flight resyncs to
  # holding, never prematurely to slide 1.
  test "state returns started false during pre-flight" do
    pair_board_session

    get board_state_path
    assert_response :success
    assert_equal({ "page" => 1, "started" => false, "ended" => false }, response.parsed_body)
  end

  test "state is not found without a board cookie" do
    get board_state_path
    assert_response :not_found
  end

  test "keyboard-nav page update clamps and broadcasts exactly the page" do
    teach_session = pair_board_session
    teach_session.update!(started_at: Time.current)

    patch board_page_path, params: { page: 99 }, as: :json
    assert_response :success
    assert_equal 8, teach_session.reload.current_page
    assert_broadcast_on TeachSessionChannel.broadcasting_for(teach_session), page: 8
  end

  test "page update is refused for an unpaired board" do
    get board_path

    patch board_page_path, params: { page: 2 }, as: :json
    assert_response :not_found
  end

  test "Esc recovery ends the session and broadcasts ended" do
    teach_session = pair_board_session

    patch board_end_path, as: :json
    assert_response :success
    assert teach_session.reload.ended?
    assert teach_session.expired?
    assert_broadcast_on TeachSessionChannel.broadcasting_for(teach_session), ended: true
  end

  private
    # Board first (sets the signed cookie), then a teacher claims the code.
    def pair_board_session(attach_files: false)
      lesson = build_kindness_lesson(attach_files: attach_files)
      get board_path
      TeachSession.last.tap do |teach_session|
        assert teach_session.claim!(lesson: lesson, teacher: users(:one))
      end
    end
end
