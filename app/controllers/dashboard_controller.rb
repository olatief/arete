class DashboardController < ApplicationController
  def show
    authorize :dashboard
    @resumable_session = TeachSession.live_for(Current.user).includes(:lesson).first
  end
end
