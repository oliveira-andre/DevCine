class Settings::PasswordsController < ApplicationController
  include ModalLayout

  # Change password in the shared modal (US4). Verifies the current password.
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    unless @user.authenticate(params.dig(:user, :current_password))
      @user.errors.add(:current_password, "is incorrect")
      return render :edit, status: :unprocessable_entity
    end

    if @user.update(password_params)
      render turbo_stream: turbo_stream.update("modal", "")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
