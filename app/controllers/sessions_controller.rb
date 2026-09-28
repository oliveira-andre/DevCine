class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  before_action :redirect_if_authenticated, only: :new
  # Two buckets: per IP (one client hammering) and per email (one account
  # targeted from many IPs — proxies/VPNs). Throttled attempts get the same
  # generic failure as a wrong password, so the limits aren't advertised.
  rate_limit to: 10, within: 3.minutes, only: :create, name: "ip",
    with: -> { render_failed_login }
  rate_limit to: 5, within: 15.minutes, only: :create, name: "email",
    by: -> { params[:email_address].to_s.strip.downcase },
    with: -> { render_failed_login }

  def new
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))

    # Blocked and login-locked accounts are rejected with the same generic
    # error and no session, so neither status is disclosed (FR-022).
    if user&.can_sign_in?
      user.reset_failed_logins!
      start_new_session_for user
      # Auth transition: the whole chrome (header/drawer/player) changes, so the
      # next render must be a full page, not a #page-content stream.
      flash[:_full_render] = true
      redirect_to after_authentication_url
    else
      # A correct password on a blocked/locked account isn't a failed guess.
      User.find_by(email_address: params[:email_address].to_s)&.register_failed_login! if user.nil?
      render_failed_login
    end
  end

  def destroy
    terminate_session
    flash[:_full_render] = true
    redirect_to new_session_path
  end

  private

  def render_failed_login
    flash[:_full_render] = true
    redirect_to new_session_path, alert: "Try another email address or password."
  end
end
