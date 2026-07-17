require 'rails_helper'

# Cross-surface gate for restricted (PIN) content — feature 006, US2/US5.
RSpec.describe "Restricted content gating", type: :request do
  let(:member) { create(:user, password: "password123") }
  let!(:restricted) do
    create(:video, :with_thumbnail, title: "Hidden Gem XyZ", kind: :standalone,
           visibility: :restricted, maturity_rating: :A18)
  end
  let!(:public_a18) do
    create(:video, :with_thumbnail, title: "Violent But Public", kind: :standalone,
           visibility: :public, maturity_rating: :A18)
  end

  before do
    post session_path, params: { email_address: member.email_address, password: "password123" }
  end

  # Unlock, then return the header both halves verified against.
  def unlock_headers
    member.update!(pin: "1234", pin_confirmation: "1234") unless member.reload.pin?
    post unlock_settings_pin_path, params: { pin: "1234" }, as: :turbo_stream
    { "X-Pin-Unlock" => session[:pin_unlock_token] }
  end

  describe "while locked" do
    it "hides the restricted title from every catalog surface but keeps public A18 visible" do
      [ root_path, videos_path, kind_browse_path(kind: "standalone"), search_path(q: "Hidden Gem") ].each do |path|
        get path
        expect(response.body).not_to include("Hidden Gem XyZ"), "leaked on #{path}"
      end

      get videos_path
      expect(response.body).to include("Violent But Public")
    end

    it "404s the restricted player page, comments, related, views and progress" do
      get player_path(restricted.slug)
      expect(response).to have_http_status(:not_found)
      get player_comments_path(restricted.slug)
      expect(response).to have_http_status(:not_found)
      get player_related_path(restricted.slug)
      expect(response).to have_http_status(:not_found)
      post player_views_path(restricted.slug)
      expect(response).to have_http_status(:not_found)
      post player_progress_path(restricted.slug), params: { position: 10 }
      expect(response).to have_http_status(:not_found)
    end

    it "keeps the restricted title out of a public video's related rail" do
      get player_related_path(public_a18.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Hidden Gem XyZ")
    end
  end

  describe "while unlocked" do
    it "lists, searches, and plays the restricted title" do
      headers = unlock_headers

      get videos_path, headers: headers
      expect(response.body).to include("Hidden Gem XyZ")

      get search_path(q: "Hidden Gem"), headers: headers
      expect(response.body).to include("Hidden Gem XyZ")

      get kind_browse_path(kind: "standalone"), headers: headers
      expect(response.body).to include("Hidden Gem XyZ")

      get player_path(restricted.slug), headers: headers
      expect(response).to have_http_status(:ok)

      get player_related_path(public_a18.slug), headers: headers
      expect(response.body).to include("Hidden Gem XyZ")
    end

    it "does not unlock with a stale/wrong header value" do
      unlock_headers
      get player_path(restricted.slug), headers: { "X-Pin-Unlock" => "forged-token" }
      expect(response).to have_http_status(:not_found)
    end

    it "never exposes another user's private video, unlocked or not" do
      private_video = create(:video, title: "Someones Secret", visibility: :private, uploader: create(:user))
      headers = unlock_headers
      get player_path(private_video.slug), headers: headers
      expect(response).to have_http_status(:not_found)
      get search_path(q: "Someones Secret"), headers: headers
      # (the page echoes the query itself; the leak test is the result link)
      expect(response.body).not_to include(player_path(private_video.slug))
      expect(response.body).to include("No results for")
    end
  end
end
