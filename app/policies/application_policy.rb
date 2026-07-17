# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # `user` is an AuthContext (viewer + PIN-unlock state) — see
  # ApplicationController#pundit_user (feature 006).
  def viewer
    user&.user
  end

  def pin_unlocked?
    user.present? && user.pin_unlocked
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope

    def viewer
      user&.user
    end

    def pin_unlocked?
      user.present? && user.pin_unlocked
    end
  end
end
