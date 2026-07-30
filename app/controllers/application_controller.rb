class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Every action must call `authorize`; the unauthenticated auth flow
  # (sessions/passwords) opts out explicitly with skip_after_action.
  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError, with: :deny_access

  private
    # Pundit's acting user comes from the authentication concern's Current.
    def pundit_user
      Current.user
    end

    def deny_access
      redirect_back fallback_location: root_path, alert: t("errors.not_authorized")
    end
end
