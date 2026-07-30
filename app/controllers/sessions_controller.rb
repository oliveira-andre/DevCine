class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  before_action :redirect_if_authenticated, only: :new
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))

    # Blocked accounts are rejected at sign-in with a generic error and no
    # session, so blocked status is never disclosed (FR-022).
    if user && !user.blocked?
      start_new_session_for user
      # Auth transition: the whole chrome (header/drawer/player) changes, so the
      # next render must be a full page, not a #page-content stream.
      flash[:_full_render] = true
      redirect_to after_authentication_url
    else
      flash[:_full_render] = true
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    flash[:_full_render] = true
    redirect_to new_session_path
  end
end
