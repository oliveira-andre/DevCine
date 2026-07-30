require 'rails_helper'

# Feature 010 (US5): the per-user autoplay preference toggle.
RSpec.describe "Settings::Autoplays", type: :request do
  let(:member) { create(:user, password: "password123") }
  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  it "flips the preference and persists it" do
    expect(member.autoplay).to be(true)

    patch settings_autoplay_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response).to have_http_status(:ok)
    expect(member.reload.autoplay).to be(false)

    patch settings_autoplay_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(member.reload.autoplay).to be(true)
  end

  it "responds with a turbo_stream replacing the toggle" do
    patch settings_autoplay_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include('target="autoplay_toggle"')
  end
end
