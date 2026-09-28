class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Reset your password", to: user.email_address
  end

  # Sent once when too many wrong passwords lock sign-in; the normal reset
  # link is also the unlock (a new password clears the lock).
  def unlock(user)
    @user = user
    mail subject: "Your account was locked — reset your password to unlock it", to: user.email_address
  end
end
