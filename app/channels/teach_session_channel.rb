# The only thing that ever crosses this channel is presence/state:
# { page: N }, { paired: true }, { started: true }, { ended: true }.
# Never notes, titles, or any lesson content — the board is unauthenticated.
#
# Never stream_from a param-built name: token → find_signed! → stream_for,
# always. The signed id authenticates but is not revocable, so subscription
# also checks the live expires_at.
class TeachSessionChannel < ApplicationCable::Channel
  def subscribed
    teach_session = TeachSession.find_signed!(params[:token], purpose: :board_stream)
    return reject if teach_session.expires_at.past?
    stream_for teach_session
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    reject
  end
end
