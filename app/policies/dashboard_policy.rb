# frozen_string_literal: true

# M0 smoke policy: any signed-in user may see the dashboard.
class DashboardPolicy < ApplicationPolicy
  def show?
    user.present?
  end
end
