require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  describe "GET /session/new" do
    it "renders the sign-in card" do
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Email")
      expect(response.body).to include("Password")
    end
  end

  describe "POST /session" do
    let(:password) { "password123" }

    it "signs in a valid, non-blocked user and redirects" do
      user = create(:user, password: password)
      post session_path, params: { email_address: user.email_address, password: password }
      expect(response).to redirect_to(root_url)
    end

    it "rejects invalid credentials with a generic alert" do
      user = create(:user, password: password)
      post session_path, params: { email_address: user.email_address, password: "wrong" }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try another email address or password.")
    end

    it "rejects a blocked user without creating a session and without disclosing the block" do
      user = create(:user, :blocked, password: password)
      post session_path, params: { email_address: user.email_address, password: password }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try another email address or password.")
      expect(user.sessions).to be_empty
    end
  end

  describe "account lockout" do
    let(:password) { "password123" }
    let(:user) { create(:user, :admin, password: password) }

    def attempt(pass, ip: "203.0.113.10")
      post session_path, params: { email_address: user.email_address, password: pass },
                         env: { "REMOTE_ADDR" => ip }
    end

    it "a correct password before the limit signs in and resets the counter" do
      (User::LOGIN_MAX_ATTEMPTS - 1).times { attempt("wrong") }
      expect(user.reload.failed_login_attempts).to eq(User::LOGIN_MAX_ATTEMPTS - 1)

      attempt(password)
      expect(response).to redirect_to(root_url)
      expect(user.reload.failed_login_attempts).to eq(0)
    end

    it "locks on the limit, emails the unlock link, and then rejects even the right password" do
      (User::LOGIN_MAX_ATTEMPTS - 1).times { attempt("wrong") }
      expect { attempt("wrong") }.to have_enqueued_mail(PasswordsMailer, :unlock)
      expect(user.reload).to be_login_locked

      attempt(password)
      expect(response).to redirect_to(new_session_path)
      # Same generic message as a wrong password — the lock isn't disclosed.
      expect(flash[:alert]).to eq("Try another email address or password.")
      expect(user.sessions).to be_empty
    end

    it "resetting the password through the normal reset link unlocks the account (role kept)" do
      User::LOGIN_MAX_ATTEMPTS.times { attempt("wrong") }
      expect(user.reload).to be_login_locked

      put password_path(user.password_reset_token),
          params: { password: "brand-new-pass1", password_confirmation: "brand-new-pass1" }
      expect(response).to redirect_to(new_session_path)

      post session_path, params: { email_address: user.email_address, password: "brand-new-pass1" }
      expect(response).to redirect_to(root_url)
      expect(user.reload).not_to be_login_locked
      expect(user).to be_admin
    end

    it "an unknown email fails generically without error" do
      post session_path, params: { email_address: "nobody@example.com", password: "x" }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try another email address or password.")
    end
  end

  describe "rate limits" do
    let(:password) { "password123" }
    let(:user) { create(:user, password: password) }
    # The test env caches to :null_store (rate limits never trip); route the
    # limiter's counter into a real store for these examples.
    let(:store) { ActiveSupport::Cache::MemoryStore.new }

    before do
      allow(SessionsController.cache_store).to receive(:increment) do |*args, **opts|
        store.increment(*args, **opts)
      end
    end

    def attempt(email, pass, ip:)
      post session_path, params: { email_address: email, password: pass }, env: { "REMOTE_ADDR" => ip }
    end

    it "throttles one IP after 10 attempts with the generic failure, without counting toward the lock" do
      10.times { |i| attempt("probe#{i}@example.com", "wrong", ip: "198.51.100.7") }

      attempt(user.email_address, password, ip: "198.51.100.7")
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try another email address or password.")
      expect(user.sessions).to be_empty

      # A different IP is unaffected.
      attempt(user.email_address, password, ip: "198.51.100.8")
      expect(response).to redirect_to(root_url)
    end

    it "throttles one email after 5 attempts even when every attempt comes from a new IP" do
      5.times { |i| attempt(user.email_address, "wrong", ip: "192.0.2.#{i + 1}") }
      expect(user.reload.failed_login_attempts).to eq(5)

      attempt(user.email_address.upcase, password, ip: "192.0.2.99")
      expect(response).to redirect_to(new_session_path)
      expect(user.sessions).to be_empty
      # Throttled requests never reach the action, so they don't count.
      expect(user.reload.failed_login_attempts).to eq(5)
    end
  end
end
