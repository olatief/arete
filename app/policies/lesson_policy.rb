class LessonPolicy < ApplicationPolicy
  # Teachers see only published lessons; drafts are an authoring concern.
  # This is policy_scope, not a CSS class — M2's library reuses it.
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.super_admin? || user&.school_admin?
        scope.all
      else
        scope.published
      end
    end
  end

  def show?
    record.published? || user.super_admin? || user.school_admin?
  end

  def teach?
    show?
  end
end
