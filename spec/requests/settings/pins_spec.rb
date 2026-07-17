require 'rails_helper'

RSpec.describe "Settings::Pins", type: :request do
  let(:member) { create(:user, password: "password123") }

  def sign_in(user = member)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  before { sign_in }

  describe "GET /settings/pin" do
    it "shows the create form when no PIN exists" do
      get settings_pin_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Create a 4–6 digit PIN")
      expect(response.body).to include("pin_confirmation")
    end

    it "shows the enter form (never the PIN) when a PIN exists" do
      member.update!(pin: "1234", pin_confirmation: "1234")
      get settings_pin_path
      expect(response.body).to include("Enter your PIN")
      expect(response.body).not_to include("1234")
    end
  end

  describe "POST /settings/pin (first-time setup)" do
    it "stores the PIN hashed" do
      post settings_pin_path, params: { pin: "4321", pin_confirmation: "4321" }, as: :turbo_stream
      expect(response).to have_http_status(:ok)
      expect(member.reload.pin?).to be(true)
      expect(member.authenticate_pin("4321")).to be_truthy
    end

    it "rejects a mismatched confirmation and stores nothing" do
      post settings_pin_path, params: { pin: "4321", pin_confirmation: "0000" }, as: :turbo_stream
      expect(response).to have_http_status(:unprocessable_content)
      expect(member.reload.pin?).to be(false)
    end

    it "rejects a non-numeric / wrong-length PIN" do
      post settings_pin_path, params: { pin: "12ab", pin_confirmation: "12ab" }, as: :turbo_stream
      expect(response).to have_http_status(:unprocessable_content)
      expect(member.reload.pin?).to be(false)
    end

    it "does not allow overwriting an existing PIN" do
      member.update!(pin: "1234", pin_confirmation: "1234")
      post settings_pin_path, params: { pin: "9999", pin_confirmation: "9999" }, as: :turbo_stream
      expect(response).to have_http_status(:unprocessable_content)
      expect(member.reload.authenticate_pin("1234")).to be_truthy
    end
  end

  describe "POST /settings/pin/unlock" do
    before { member.update!(pin: "1234", pin_confirmation: "1234") }

    it "mints the session unlock token and hands it to the client" do
      post unlock_settings_pin_path, params: { pin: "1234" }, as: :turbo_stream
      expect(response).to have_http_status(:ok)
      expect(session[:pin_unlock_token]).to be_present
      expect(response.body).to include(session[:pin_unlock_token])
      expect(response.body).to include("pin-lock-handoff")
    end

    it "resets the failed-attempt counter on success" do
      member.update!(pin_attempts: 2)
      post unlock_settings_pin_path, params: { pin: "1234" }, as: :turbo_stream
      expect(member.reload.pin_attempts).to eq(0)
    end

    it "increments attempts and re-renders on a wrong PIN" do
      post unlock_settings_pin_path, params: { pin: "0000" }, as: :turbo_stream
      expect(response).to have_http_status(:unprocessable_content)
      expect(member.reload.pin_attempts).to eq(1)
      expect(session[:pin_unlock_token]).to be_blank
    end

    it "rejects unlock when no PIN exists" do
      member.update_column(:pin_digest, nil)
      post unlock_settings_pin_path, params: { pin: "1234" }, as: :turbo_stream
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "three strikes (US3)" do
    before { member.update!(pin: "1234", pin_confirmation: "1234") }

    it "blocks the account and terminates the session on the third wrong PIN" do
      2.times { post unlock_settings_pin_path, params: { pin: "0000" }, as: :turbo_stream }
      expect(member.reload.pin_attempts).to eq(2)
      expect(member).not_to be_blocked

      post unlock_settings_pin_path, params: { pin: "0000" }, as: :turbo_stream
      expect(response.body).to include("data-redirect-url-value")
      expect(response.body).to include(new_session_path)
      expect(member.reload).to be_blocked

      # The session is gone: any authenticated page bounces to sign-in.
      get account_path
      expect(response).to redirect_to(new_session_path)

      # And the blocked account cannot sign back in (existing generic error).
      post session_path, params: { email_address: member.email_address, password: "password123" }
      expect(response).to redirect_to(new_session_path)
      get account_path
      expect(response).to redirect_to(new_session_path)
    end

    it "a correct PIN before the third failure resets the counter" do
      2.times { post unlock_settings_pin_path, params: { pin: "0000" }, as: :turbo_stream }
      post unlock_settings_pin_path, params: { pin: "1234" }, as: :turbo_stream
      expect(member.reload.pin_attempts).to eq(0)
      expect(member).not_to be_blocked
    end
  end
end
