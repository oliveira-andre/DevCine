require "rails_helper"

# The lockout email (PasswordsMailer#unlock): the only way back in for a
# locked-out user, so its link must be a working password-reset link.
RSpec.describe PasswordsMailer, type: :mailer do
  describe "#unlock" do
    let(:user) { create(:user, password: "password123") }
    let(:mail) { described_class.unlock(user) }

    def reset_token(part)
      part.body.decoded[%r{/passwords/([^/\s"<]+)/edit}, 1]
    end

    it "goes to the locked user with the unlock subject" do
      expect(mail.to).to eq([ user.email_address ])
      expect(mail.subject).to eq("Your account was locked — reset your password to unlock it")
    end

    it "explains the lock and links to the normal reset page, in both parts" do
      [ mail.html_part, mail.text_part ].each do |part|
        body = part.body.decoded
        expect(body).to include("#{User::LOGIN_MAX_ATTEMPTS} wrong")
        expect(body).to include("Forgot your password?")
        expect(User.find_by_password_reset_token!(reset_token(part))).to eq(user)
      end
    end

    it "the link is single-use: it stops resolving once the password changes" do
      token = reset_token(mail.text_part)
      user.update!(password: "brand-new-pass1", password_confirmation: "brand-new-pass1")

      expect { User.find_by_password_reset_token!(token) }
        .to raise_error(ActiveSupport::MessageVerifier::InvalidSignature)
    end
  end
end
