class TeachSessionPolicy < ApplicationPolicy
  # Any signed-in user may pair a board and teach.
  def new?
    user.present?
  end

  def pair?
    new?
  end

  # Driving an existing session is the pairing teacher only.
  def update?
    user.present? && record.teacher_id == user.id
  end

  def companion? = update?
  def state?     = update?
  def start?     = update?
  def finish?    = update?
end
