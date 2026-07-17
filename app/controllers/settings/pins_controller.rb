class Settings::PinsController < ApplicationController
  include ModalLayout

  # GET /settings/pin — the lock-icon modal: create-PIN form (no PIN yet),
  # enter-PIN form (PIN set, locked), or an unlocked confirmation.
  def show
    @user = Current.user
  end

  # POST /settings/pin — first-time PIN setup (US1). Changing an existing PIN
  # is out of scope, so an existing digest rejects.
  def create
    @user = Current.user
    if @user.pin?
      head :unprocessable_entity
    elsif @user.update(pin_params)
      render :created
    else
      render :show, status: :unprocessable_entity
    end
  end

  # POST /settings/pin/unlock — verify the PIN (US2). Success mints the session
  # half of the unlock token and hands the client half to pin-lock JS. A wrong
  # PIN counts toward User::PIN_MAX_ATTEMPTS; the final strike blocks the
  # account and terminates the session (US3).
  def unlock
    @user = Current.user
    return head :unprocessable_entity unless @user.pin?

    if @user.authenticate_pin(params[:pin].to_s)
      @user.reset_pin_attempts!
      @token = SecureRandom.hex(16)
      session[:pin_unlock_token] = @token
      render :unlocked
    elsif @user.register_failed_pin_attempt! == :blocked
      terminate_session
      # Break out of the modal frame to a full-page sign-in (US3).
      render turbo_stream: turbo_stream.append(
        "body",
        %(<div data-controller="redirect" data-redirect-url-value="#{new_session_path}" hidden></div>).html_safe
      )
    else
      flash.now[:pin_error] = true
      render :show, status: :unprocessable_entity
    end
  end

  private

  def pin_params
    params.permit(:pin, :pin_confirmation)
  end
end
