# The classroom projector. No user, no navigation — authorized by a signed
# httponly cookie holding the TeachSession id. Everything it renders is
# content the room is already looking at; teacher notes never come here.
class BoardsController < ApplicationController
  allow_unauthenticated_access
  skip_after_action :verify_authorized # device is cookie-authorized, no Pundit user

  layout "presenter"

  def show
    @teach_session = current_board_session

    if @teach_session.nil? || @teach_session.ended? || @teach_session.expired?
      @teach_session = issue_board_session!
    end

    if @teach_session.paired?
      @lesson = @teach_session.lesson
      @slides = @lesson.slides.with_attached_image
      render :lesson
    else
      render :waiting
    end
  end

  # Resync target for a reconnecting board (and regression guard: a board that
  # reconnects during pre-flight must land on holding, never slide 1).
  def state
    teach_session = current_board_session or return head(:not_found)

    render json: {
      page: teach_session.current_page,
      started: teach_session.started?,
      ended: teach_session.ended?
    }
  end

  # Keyboard-nav fallback (←/→/space): if the phone dies, the teacher walks to
  # the PC and keeps going. Same broadcast shape as the phone's update.
  def update_page
    teach_session = current_board_session
    return head :not_found unless teach_session&.paired?
    return head :gone if teach_session.ended? || teach_session.expired?

    page = params.require(:page).to_i.clamp(1, [ teach_session.lesson.slides.count, 1 ].max)
    teach_session.update!(current_page: page, last_seen_at: Time.current)
    TeachSessionChannel.broadcast_to(teach_session, { page: teach_session.current_page })
    head :ok
  end

  # Esc recovery: end the session from the board so a dead phone can't strand
  # the class — the board then reissues itself a fresh code via #show.
  def finish
    teach_session = current_board_session
    return head :not_found unless teach_session&.paired?

    unless teach_session.ended?
      teach_session.update!(ended_at: Time.current, expires_at: Time.current)
      TeachSessionChannel.broadcast_to(teach_session, { ended: true })
    end
    head :ok
  end

  private
    def current_board_session
      TeachSession.find_by(id: cookies.signed[:board_session_id])
    end

    def issue_board_session!
      TeachSession.issue!.tap do |teach_session|
        cookies.signed[:board_session_id] = {
          value: teach_session.id, httponly: true, same_site: :lax
        }
      end
    end
end
