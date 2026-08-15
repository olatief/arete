require "test_helper"

class TeachSessionsControllerTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

  setup do
    @lesson = build_kindness_lesson
    @teacher = users(:one)
    sign_in_as @teacher
  end

  test "teach form renders for a published lesson" do
    get lesson_teach_path(@lesson)
    assert_response :success
    assert_includes response.body, @lesson.title
  end

  test "teach form is not found for a draft lesson" do
    @lesson.update!(published_at: nil)
    get lesson_teach_path(@lesson)
    assert_response :not_found
  end

  test "pairing claims the code single-use and redirects to the companion" do
    teach_session = TeachSession.issue!

    post pair_teach_sessions_path, params: { code: teach_session.pairing_code, lesson_id: @lesson.id }

    assert_redirected_to companion_teach_session_path(teach_session)
    teach_session.reload
    assert_nil teach_session.pairing_code
    assert_equal @teacher, teach_session.teacher
    assert_equal @lesson, teach_session.lesson
    assert teach_session.paired?
    assert teach_session.expires_at > 11.hours.from_now
    assert_broadcast_on TeachSessionChannel.broadcasting_for(teach_session), paired: true
  end

  test "pairing accepts the grouped lowercase form of the code" do
    teach_session = TeachSession.issue!
    typed = teach_session.pairing_code.downcase.scan(/.{1,3}/).join(" ")

    post pair_teach_sessions_path, params: { code: typed, lesson_id: @lesson.id }
    assert_redirected_to companion_teach_session_path(teach_session)
  end

  # Test 2: the code is nulled on pair — a second redeem fails.
  test "a pairing code is single use" do
    teach_session = TeachSession.issue!
    code = teach_session.pairing_code

    post pair_teach_sessions_path, params: { code: code, lesson_id: @lesson.id }
    assert_redirected_to companion_teach_session_path(teach_session)

    post pair_teach_sessions_path, params: { code: code, lesson_id: @lesson.id }
    assert_redirected_to lesson_teach_path(@lesson)
    assert_equal I18n.t("teach_sessions.pair.not_found"), flash[:alert]
  end

  # Test 3: codes expire in minutes, not hours.
  test "an expired code cannot be redeemed" do
    teach_session = TeachSession.issue!

    travel 5.minutes do
      post pair_teach_sessions_path, params: { code: teach_session.pairing_code, lesson_id: @lesson.id }
    end

    assert_redirected_to lesson_teach_path(@lesson)
    assert_not teach_session.reload.paired?
  end

  test "the failure message does not distinguish unknown from expired" do
    expired = TeachSession.issue!
    travel 5.minutes do
      post pair_teach_sessions_path, params: { code: expired.pairing_code, lesson_id: @lesson.id }
      expired_alert = flash[:alert]

      post pair_teach_sessions_path, params: { code: "666666", lesson_id: @lesson.id }
      assert_equal expired_alert, flash[:alert]
    end
  end

  # Test 7: burst axis — the 6th attempt inside a minute is refused.
  test "pairing is rate limited to 5 attempts per minute" do
    5.times do
      post pair_teach_sessions_path, params: { code: "222222", lesson_id: @lesson.id }
      assert_response :redirect
    end

    post pair_teach_sessions_path, params: { code: "222222", lesson_id: @lesson.id }
    assert_response :too_many_requests
  end

  test "guessing one code is rate limited on its own axis" do
    10.times do |attempt|
      travel((attempt * 61).seconds) do # spaced out to stay under the burst axis
        post pair_teach_sessions_path, params: { code: "777777", lesson_id: @lesson.id }
        assert_response :redirect
      end
    end

    travel 11.minutes do
      post pair_teach_sessions_path, params: { code: "777777", lesson_id: @lesson.id }
      assert_response :too_many_requests
    end
  end

  # Test 4 — THE PAYLOAD AUDIT. This test must never be deleted. The board is
  # an unauthenticated subscriber: the advance broadcast's keys are exactly
  # ["page"], and nothing that ever crosses the stream may contain lesson
  # content (notes, titles, prime).
  test "cable payloads are state only — never notes, titles, or content" do
    teach_session = pair!
    stream = TeachSessionChannel.broadcasting_for(teach_session)

    patch start_teach_session_path(teach_session)
    patch teach_session_path(teach_session), params: { page: 2 }, as: :json
    patch finish_teach_session_path(teach_session)

    payloads = broadcasts(stream).map { |raw| JSON.parse(raw) }
    assert_equal [ [ "paired" ], [ "started" ], [ "page" ], [ "ended" ] ], payloads.map(&:keys)
    assert_includes payloads, { "page" => 2 }

    wire = broadcasts(stream).join
    [
      @lesson.title,                       # lesson title
      @lesson.prime[0, 40],                # prime
      @lesson.close_prompt,                # close prompt
      "Two words that look alike",         # a slide title
      "spinach in your teeth"              # a distinctive notes fragment
    ].each do |fragment|
      assert_not_includes wire, fragment
    end
  end

  test "advancing clamps to the deck and stores absolute state" do
    teach_session = pair!

    patch teach_session_path(teach_session), params: { page: 999 }, as: :json
    assert_response :success
    assert_equal 8, teach_session.reload.current_page

    patch teach_session_path(teach_session), params: { page: 0 }, as: :json
    assert_equal 1, teach_session.reload.current_page
    assert_not_nil teach_session.last_seen_at
  end

  # Test 8: driving a session is the pairing teacher only.
  test "another teacher cannot drive someone else's session" do
    teach_session = pair!
    sign_in_as users(:two)

    patch teach_session_path(teach_session), params: { page: 5 }, as: :json
    assert_response :redirect
    assert_equal 1, teach_session.reload.current_page

    patch finish_teach_session_path(teach_session)
    assert_not teach_session.reload.ended?

    get companion_teach_session_path(teach_session)
    assert_response :redirect
  end

  test "start is a deliberate act that flips holding to teaching" do
    teach_session = pair!
    assert teach_session.holding?

    patch start_teach_session_path(teach_session)
    assert_redirected_to companion_teach_session_path(teach_session)
    assert teach_session.reload.started?
    assert_broadcast_on TeachSessionChannel.broadcasting_for(teach_session), started: true
  end

  test "state reports page, started and ended to the teacher" do
    teach_session = pair!

    get state_teach_session_path(teach_session)
    assert_equal({ "page" => 1, "started" => false, "ended" => false }, response.parsed_body)
  end

  test "ending expires the session immediately" do
    teach_session = pair!

    patch finish_teach_session_path(teach_session)
    assert_redirected_to root_path
    teach_session.reload
    assert teach_session.ended?
    assert teach_session.expired?
    assert_broadcast_on TeachSessionChannel.broadcasting_for(teach_session), ended: true

    patch teach_session_path(teach_session), params: { page: 2 }, as: :json
    assert_response :gone
  end

  test "teach form offers resume instead of a code when a live session exists" do
    teach_session = pair!

    get lesson_teach_path(@lesson)
    assert_response :success
    assert_includes response.body, ERB::Util.html_escape(I18n.t("teach_sessions.resume.same_lesson"))
    assert_includes response.body, companion_teach_session_path(teach_session)
  end

  test "resume names the lesson when the live session is for another lesson" do
    pair!
    other = @lesson.unit.lessons.create!(
      position: 9, code: "AR-G06-U2-L09", locale: "en",
      title: "A Different Lesson", published_at: Time.current
    )

    get lesson_teach_path(other)
    assert_includes response.body, ERB::Util.html_escape(I18n.t("teach_sessions.resume.other_lesson", title: @lesson.title))
  end

  test "no resume is offered for ended or expired sessions" do
    teach_session = pair!
    patch finish_teach_session_path(teach_session)

    get lesson_teach_path(@lesson)
    assert_not_includes response.body, ERB::Util.html_escape(I18n.t("teach_sessions.resume.same_lesson"))

    stale = pair!
    travel 13.hours do
      get lesson_teach_path(@lesson)
      assert_not_includes response.body, companion_teach_session_path(stale)
    end
  end

  test "resume is scoped to the signed-in teacher" do
    teach_session = pair!
    sign_in_as users(:two)

    get lesson_teach_path(@lesson)
    assert_not_includes response.body, companion_teach_session_path(teach_session)
  end

  test "the dashboard offers resume for a live session" do
    teach_session = pair!

    get root_path
    assert_includes response.body, I18n.t("teach_sessions.resume.action", page: teach_session.current_page)
    assert_includes response.body, companion_teach_session_path(teach_session)
  end

  test "ending a stale session from the teach form returns to the form" do
    teach_session = pair!

    patch finish_teach_session_path(teach_session),
          headers: { "HTTP_REFERER" => lesson_teach_path(@lesson) }
    assert_redirected_to lesson_teach_path(@lesson)
    assert teach_session.reload.ended?
  end

  test "companion renders every note server-side at load" do
    attach_slide_images!
    teach_session = pair!
    patch start_teach_session_path(teach_session)

    get companion_teach_session_path(teach_session)
    assert_response :success
    # All 8 scripts are in the HTML up front — notes never cross the wire.
    assert_includes response.body, "spinach in your teeth"
    assert_includes response.body, "count it"
    assert_equal 8, response.body.scan("data-companion-target=\"page\"").size
  end

  private
    def pair!
      teach_session = TeachSession.issue!
      post pair_teach_sessions_path, params: { code: teach_session.pairing_code, lesson_id: @lesson.id }
      teach_session.reload
    end

    def attach_slide_images!
      @lesson.slides.each do |slide|
        slide.image.attach(
          io: File.open(KindnessLessonData.slide_image_file(slide.page_number)),
          filename: "kindness-slide-#{slide.page_number}.png",
          content_type: "image/png"
        )
      end
    end
end
