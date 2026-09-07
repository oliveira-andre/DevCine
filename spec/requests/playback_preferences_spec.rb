require 'rails_helper'

# Per-title playback memory: PATCH /playing/:slug/preference stores the
# viewer's audio/subtitle choice against the TITLE (serie/movie/standalone
# video) — one row per (user, title), updated in place forever after — and the
# player preloads it on show and in the up-next descriptor.
RSpec.describe "Playback preferences", type: :request do
  let(:member) { create(:user, password: "password123") }
  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  def serie_with_episodes(*videos)
    serie = create(:serie)
    season = create(:season, serie: serie, position: 1)
    videos.each_with_index { |v, i| create(:episode, season: season, video: v, position: i + 1) }
    serie
  end

  describe "PATCH /playing/:slug/preference" do
    it "creates one row for the serie, then updates it — never a second row" do
      e1, e2 = create_list(:video, 2, :with_file, visibility: :public)
      serie = serie_with_episodes(e1, e2)

      expect {
        patch preference_player_path(e1.slug), params: { audio_track_name: "English" }, as: :json
      }.to change(PlaybackPreference, :count).by(1)
      expect(response).to have_http_status(:no_content)

      preference = member.playback_preferences.sole
      expect(preference.watchable).to eq(serie)
      expect(preference.audio_track_name).to eq("English")

      # A change from ANY episode of the same serie updates that same row.
      expect {
        patch preference_player_path(e2.slug), params: { audio_track_name: "Português" }, as: :json
      }.not_to change(PlaybackPreference, :count)
      expect(preference.reload.audio_track_name).to eq("Português")
    end

    it "keeps audio and subtitle choices on the same row without clobbering each other" do
      video = create(:video, :with_file, visibility: :public, kind: :standalone)

      patch preference_player_path(video.slug), params: { audio_track_name: "English" }, as: :json
      patch preference_player_path(video.slug), params: { subtitle_language: "portuguese" }, as: :json

      preference = member.playback_preferences.sole
      expect(preference.audio_track_name).to eq("English")
      expect(preference.subtitle_language).to eq("portuguese")
    end

    it "creates separate rows for different titles" do
      episode = create(:video, :with_file, visibility: :public)
      serie_with_episodes(episode)
      movie = create(:movie, video: create(:video, :with_file, visibility: :public))

      patch preference_player_path(episode.slug), params: { audio_track_name: "English" }, as: :json
      patch preference_player_path(movie.video.slug), params: { audio_track_name: "Português" }, as: :json

      expect(member.playback_preferences.count).to eq(2)
      expect(member.playback_preferences.pluck(:watchable_type)).to match_array(%w[Serie Movie])
    end

    it "requires authentication" do
      delete session_path
      video = create(:video, :with_file, visibility: :public)
      patch preference_player_path(video.slug), params: { audio_track_name: "English" }, as: :json
      expect(response).to redirect_to(new_session_path)
    end

    it "404s for a private video the viewer cannot watch" do
      video = create(:video, :with_file, visibility: :private, uploader: create(:user))
      patch preference_player_path(video.slug), params: { audio_track_name: "English" }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "preloading on the player page" do
    it "renders the remembered audio track preselected and exposes both ids" do
      video = create(:video, :with_file, visibility: :public)
      serie = serie_with_episodes(video)
      video.audio_tracks.create!(name: "Português", position: 1)
      english = video.audio_tracks.create!(name: "English", position: 2)
      english.file.attach(io: StringIO.new("m4a"), filename: "english.m4a", content_type: "audio/mp4")
      subtitle = create(:subtitle, :with_file, video: video, language: :portuguese)
      create(:playback_preference, user: member, watchable: serie,
             audio_track_name: "English", subtitle_language: "portuguese")

      get player_path(video.slug)
      expect(response.body).to include(%(data-player-source-preferred-audio-id-value="#{english.id}"))
      expect(response.body).to include(%(data-player-source-preferred-subtitle-id-value="#{subtitle.id}"))
      expect(response.body).to match(/<option value="#{english.id}"\s+selected>/)
    end

    it "falls back to the defaults when the title has no preference yet" do
      video = create(:video, :with_file, visibility: :public, kind: :standalone)
      get player_path(video.slug)
      expect(response.body).to include(%(data-player-source-preferred-audio-id-value=""))
      expect(response.body).to include(%(data-player-source-preferred-subtitle-id-value=""))
    end
  end

  describe "up-next descriptor" do
    it "carries the resolved preference ids for the next episode" do
      e1, e2 = create_list(:video, 2, :with_file, visibility: :public)
      serie = serie_with_episodes(e1, e2)
      e2.audio_tracks.create!(name: "Português", position: 1)
      english = e2.audio_tracks.create!(name: "English", position: 2)
      english.file.attach(io: StringIO.new("m4a"), filename: "english.m4a", content_type: "audio/mp4")
      create(:playback_preference, user: member, watchable: serie, audio_track_name: "English")

      get up_next_player_path(e1.slug)
      body = JSON.parse(response.body)
      expect(body["preferredAudioId"]).to eq(english.id)
      expect(body["preferredSubtitleId"]).to be_nil
    end

    it "resolves to nil when the next episode lacks the preferred track — defaults apply, no failure" do
      e1, e2 = create_list(:video, 2, :with_file, visibility: :public)
      serie = serie_with_episodes(e1, e2)
      # E2 carries neither an "English" audio track nor an english subtitle;
      # the client falls back to the default (or first) track on nil.
      e2.audio_tracks.create!(name: "Português", position: 1)
      create(:subtitle, :with_file, video: e2, language: :portuguese, is_default: true)
      create(:playback_preference, user: member, watchable: serie,
             audio_track_name: "English", subtitle_language: "english")

      get up_next_player_path(e1.slug)
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["preferredAudioId"]).to be_nil
      expect(body["preferredSubtitleId"]).to be_nil

      # Same miss on a full page load: empty ids → the menus preselect defaults.
      get player_path(e2.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(data-player-source-preferred-audio-id-value=""))
      expect(response.body).to include(%(data-player-source-preferred-subtitle-id-value=""))
    end
  end
end
