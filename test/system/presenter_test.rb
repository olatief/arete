require "application_system_test_case"

# Two-device flows: :board is the projector (unauthenticated), the default
# Capybara session is the teacher's phone.
class PresenterTest < ApplicationSystemTestCase
  setup do
    @lesson = build_kindness_lesson(attach_files: true)
    @teacher = users(:one)
  end

  # Test 1: pair → start → advance; board and phone both agree on the page.
  test "pairing and advancing keeps board and phone on the same page" do
    code = open_board
    pair_phone(code)

    using_session(:board) do
      assert_selector "[data-board-target='holding']:not(.hidden)", wait: 10 # holding, not slide 1
    end

    click_on I18n.t("teach_sessions.companion.start")
    assert_text "1 / 8", wait: 10

    using_session(:board) do
      assert_selector "img.slide-layer.is-active[data-page='1']", wait: 10
    end

    click_on I18n.t("teach_sessions.companion.next")
    assert_text "2 / 8", wait: 10

    using_session(:board) do
      assert_selector "img.slide-layer.is-active[data-page='2']", wait: 10
    end
  end

  # Test 6: a board that loses its websocket keeps showing the current slide
  # and resyncs to current_page on reconnect.
  test "board survives a killed websocket and resyncs on reconnect" do
    code = open_board
    pair_phone(code)
    click_on I18n.t("teach_sessions.companion.start")

    using_session(:board) do
      assert_selector "img.slide-layer.is-active[data-page='1']", wait: 10
      page.execute_script("window.cableConsumer.connection.close({ allowReconnect: false })")
    end

    click_on I18n.t("teach_sessions.companion.next")
    assert_text "2 / 8", wait: 10

    using_session(:board) do
      # The projector never blanks — it stays on the slide it had.
      assert_selector "img.slide-layer.is-active[data-page='1']"

      page.execute_script("window.cableConsumer.connection.open()")
      page.execute_script("window.dispatchEvent(new Event('board:resync'))")
      assert_selector "img.slide-layer.is-active[data-page='2']", wait: 10
    end
  end

  # Test 9: a board reconnecting during pre-flight lands on holding, never
  # prematurely on slide 1.
  test "board resyncing during pre-flight shows holding, not slide 1" do
    code = open_board
    pair_phone(code)

    using_session(:board) do
      assert_selector "[data-board-target='holding']:not(.hidden)", wait: 10
      page.execute_script("window.dispatchEvent(new Event('board:resync'))")
      sleep 0.5
      assert_selector "[data-board-target='holding']:not(.hidden)"
      assert_no_selector "img.slide-layer.is-active"
    end
  end

  # Test 10: ending needs the in-page confirmation; afterwards the board
  # auto-issues itself a fresh, redeemable code.
  test "ending confirms first, then the board shows a fresh working code" do
    code = open_board
    pair_phone(code)
    click_on I18n.t("teach_sessions.companion.start")
    assert_text "1 / 8", wait: 10

    click_on I18n.t("teach_sessions.companion.end")
    # Confirmation panel, in-page — nothing ended yet.
    assert_text I18n.t("teach_sessions.companion.confirm_end")
    assert_not TeachSession.last.ended?

    click_on I18n.t("teach_sessions.companion.confirm")
    assert_text I18n.t("teach_sessions.ended_notice"), wait: 10

    fresh_code = nil
    using_session(:board) do
      assert_text I18n.t("boards.waiting.code_expires_in"), wait: 10
      fresh_session = TeachSession.order(:id).last
      assert_not_nil fresh_session.pairing_code
      fresh_code = fresh_session.pairing_code
    end

    # The fresh code drives a brand-new session end to end.
    pair_phone(fresh_code)
    assert_text I18n.t("teach_sessions.companion.start"), wait: 10
  end

  private
    def open_board
      using_session(:board) do
        visit board_path
        assert_text I18n.t("boards.waiting.code_expires_in")
      end
      TeachSession.order(:id).last.pairing_code
    end

    def pair_phone(code)
      visit new_session_path
      fill_in "email_address", with: @teacher.email_address
      fill_in "password", with: "password"
      click_on I18n.t("sessions.new.submit")
      assert_text I18n.t("dashboard.show.title")

      visit lesson_teach_path(@lesson)
      fill_in "code", with: code
      click_on I18n.t("teach_sessions.new.submit")
      assert_text I18n.t("teach_sessions.companion.paired_ok"), wait: 10
    end
end
