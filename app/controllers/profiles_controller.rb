class ProfilesController < ApplicationController
  include ModalLayout

  # Avatar + cover update, rendered in the shared modal (US3).
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(profile_params)
      render turbo_stream: [
        turbo_stream.update("modal", ""),
        turbo_stream.replace("account_avatar", partial: "accounts/avatar", locals: { user: @user }),
        turbo_stream.replace("account_bg", partial: "accounts/background", locals: { user: @user })
      ]
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Inline display-name edit via the "account_name" Turbo frame (owner only).
  def edit_name
    @user = Current.user
  end

  def update_name
    @user = Current.user

    if @user.update(name_params)
      render partial: "accounts/name", locals: { user: @user, owner: true }
    else
      render :edit_name, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:avatar, :cover)
  end

  def name_params
    params.require(:user).permit(:display_name)
  end
end
