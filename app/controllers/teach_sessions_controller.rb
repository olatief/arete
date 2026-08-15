class TeachSessionsController < ApplicationController
  # Two axes, stacked: a burst of guesses from one IP and a distributed guess
  # of one code both hit a wall. Requires a cache store with atomic increment
  # (Solid Cache; never :memory_store or :null_store).
  rate_limit to: 5,  within: 1.minute, only: :pair, name: "burst"
  rate_limit to: 20, within: 1.hour,   only: :pair, name: "hourly"
  rate_limit to: 10, within: 1.hour,   only: :pair, name: "per_code",
             by: -> { params[:code].to_s.upcase }

  layout "presenter"

  # Code entry form, reached from a lesson's Teach button.
  def new
    @lesson = find_lesson(params[:lesson_id])
    authorize @lesson, :teach?
  end

  def pair
    authorize TeachSession, :pair?
    @lesson = find_lesson(params[:lesson_id])

    code = TeachSession.normalize_pairing_code(params[:code])
    teach_session = TeachSession.claimable.find_by(pairing_code: code)

    if @lesson.slides.none?
      redirect_to lesson_teach_path(@lesson), alert: t("teach_sessions.pair.no_slides")
    elsif teach_session&.claim!(lesson: @lesson, teacher: Current.user)
      TeachSessionChannel.broadcast_to(teach_session, { paired: true })
      redirect_to companion_teach_session_path(teach_session)
    else
      # Deliberately generic — distinguishing "not found" from "expired" turns
      # the form into an oracle for guessing codes (UX-SPEC §9).
      redirect_to lesson_teach_path(@lesson), alert: t("teach_sessions.pair.not_found")
    end
  end

  def companion
    @teach_session = authorize find_teach_session
    return redirect_to root_path, notice: t("teach_sessions.ended_notice") if @teach_session.ended?

    @lesson = @teach_session.lesson
    @slides = @lesson.slides.with_attached_image
  end

  # Phone-side resync mirror of BoardsController#state.
  def state
    teach_session = authorize find_teach_session

    render json: {
      page: teach_session.current_page,
      started: teach_session.started?,
      ended: teach_session.ended?
    }
  end

  # The hot path. The payload is exactly { page: N } — absolute, never a
  # delta, never any lesson content (CLAUDE.md rules 1 & 5).
  def update
    teach_session = authorize find_teach_session
    return head :gone if teach_session.ended? || teach_session.expired?

    page = params.require(:page).to_i.clamp(1, [ teach_session.lesson.slides.count, 1 ].max)
    teach_session.update!(current_page: page, last_seen_at: Time.current)
    TeachSessionChannel.broadcast_to(teach_session, { page: teach_session.current_page })
    head :ok
  end

  # Pre-flight Start: beginning the lesson is a deliberate act — until now the
  # board shows the holding screen, never slide 1 (UX-SPEC §5.3).
  def start
    teach_session = authorize find_teach_session
    return redirect_to root_path, notice: t("teach_sessions.ended_notice") if teach_session.ended?

    unless teach_session.started?
      teach_session.update!(started_at: Time.current, last_seen_at: Time.current)
      TeachSessionChannel.broadcast_to(teach_session, { started: true })
    end
    redirect_to companion_teach_session_path(teach_session)
  end

  def finish
    teach_session = authorize find_teach_session

    unless teach_session.ended?
      teach_session.update!(ended_at: Time.current, expires_at: Time.current)
      TeachSessionChannel.broadcast_to(teach_session, { ended: true })
    end
    redirect_to root_path, notice: t("teach_sessions.ended_notice")
  end

  private
    def find_teach_session
      TeachSession.find(params[:id])
    end

    def find_lesson(id)
      policy_scope(Lesson).find(id)
    end
end
