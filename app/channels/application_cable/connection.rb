module ApplicationCable
  class Connection < ActionCable::Connection::Base
    # Permissive on purpose: the board is an unauthenticated subscriber (a
    # projector), so current_user may be nil. Authorization happens per-channel
    # — TeachSessionChannel requires a signed session token to subscribe.
    identified_by :current_user

    def connect
      self.current_user = find_authenticated_user
    end

    private
      def find_authenticated_user
        Session.find_by(id: cookies.signed[:session_id])&.user
      end
  end
end
