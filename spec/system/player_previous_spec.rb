require 'rails_helper'

# "Previous" follows the music-player convention: past the first 5 seconds it
# rewinds the current video; a press inside that window goes to the previous
# video in the sequence. Headless Selenium can't reliably decode media (see
# mini_player_spec.rb), so the <video>'s currentTime is stubbed and every write
# is mirrored onto a data attribute for Capybara to wait on.
RSpec.describe "Player previous control", type: :system do
  let(:user) { create(:user, password: "password123") }
  let(:first_video) { create(:video, :with_thumbnail, :with_file, title: "Episode One", visibility: :public) }
  let(:second_video) { create(:video, :with_thumbnail, :with_file, title: "Episode Two", visibility: :public) }
  let(:playlist) { create(:playlist, user: user) }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  def stub_current_time(seconds)
    page.execute_script(<<~JS, seconds)
      const video = document.querySelector("#mini-player video");
      let time = arguments[0];
      Object.defineProperty(video, "currentTime", {
        configurable: true,
        get: () => time,
        set: (t) => { time = t; document.body.dataset.seekedTo = String(t); }
      });
    JS
  end

  def click_prev
    # Clicked via script: the button is pointer-events:none until the player
    # chrome is active, and chrome activation is not what this spec covers.
    page.execute_script(%{document.querySelector('[data-action="mini-player#prev"]').click()})
  end

  before do
    create(:playlist_item, playlist: playlist, video: first_video, position: 1)
    create(:playlist_item, playlist: playlist, video: second_video, position: 2)
    sign_in_as(user)
    visit player_path(second_video.slug, list: playlist.id)
    expect(page).to have_css("#mini-player.mini-player--expanded", visible: :all)
    expect(page).to have_css("[data-mini-player-target='prevBtn']:not([hidden])", visible: :all)
  end

  it "rewinds to the start when past 5 seconds, then goes back on a second press" do
    stub_current_time(600)

    click_prev
    expect(page).to have_css("body[data-seeked-to='0']")
    expect(page).to have_current_path(player_path(second_video.slug, list: playlist.id))

    click_prev
    expect(page).to have_current_path(player_path(first_video.slug, list: playlist.id))
  end

  it "goes straight to the previous video within the first 5 seconds" do
    stub_current_time(3)

    click_prev

    expect(page).to have_current_path(player_path(first_video.slug, list: playlist.id))
    expect(page).to have_no_css("body[data-seeked-to]")
  end
end
