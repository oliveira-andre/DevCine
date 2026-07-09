class AccountsController < ApplicationController
  # Minimal placeholder account page (full account management is a later feature).
  def show
    @user = Current.user
  end
end
