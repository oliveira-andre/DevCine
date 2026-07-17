class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError do
    raise ActiveRecord::RecordNotFound
  end

  # Policies receive the viewer AND the PIN-unlock state (feature 006, FR-017).
  def pundit_user
    AuthContext.new(user: Current.user, pin_unlocked: pin_unlocked?)
  end

  private

  def pin_unlocked?
    token = request.headers["X-Pin-Unlock"]
    expected = session[:pin_unlock_token]
    token.present? && expected.present? &&
      ActiveSupport::SecurityUtils.secure_compare(token, expected)
  end
  helper_method :pin_unlocked?
end
