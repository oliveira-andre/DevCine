require 'rails_helper'

# US1: create a playlist inline from the player's add-to-playlist popover, then
# add the current video to it.
RSpec.describe "Inline playlist create (player)", type: :system do
  let(:user) { create(:user, password: "password123") }
  let(:video) { create(:video, :with_thumbnail, title: "Some Clip", visibility: :public) }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  def open_add_to_playlist
    visit player_path(video.slug)
    find("button[aria-label='More options']").click
    click_link "Add to playlist"
    expect(page).to have_css("#playlist-add-create")
  end

  before { sign_in_as(user) }

  it "reveals an inline input and cancels without creating" do
    open_add_to_playlist
    within("#playlist-add-create") do
      click_button "Add a playlist"
      expect(page).to have_css("input[name='playlist[title]']", visible: :visible)
      # The "Add a playlist" button is hidden while editing…
      expect(page).to have_no_button("Add a playlist")
      find("button[aria-label='Cancel']").click
      # …and reappears on cancel.
      expect(page).to have_button("Add a playlist")
    end
    expect(user.playlists.pluck(:title)).not_to include("")
  end

  it "creates a playlist inline and adds the current video to it" do
    open_add_to_playlist
    within("#playlist-add-create") do
      click_button "Add a playlist"
      fill_in "playlist[title]", with: "My Faves"
      find("button[aria-label='Create playlist']").click
    end

    # New row appears in the list and the control resets to the button.
    within("#playlist-add-list") { expect(page).to have_content("My Faves") }
    expect(page).to have_button("Add a playlist")
    expect(user.playlists.reload.pluck(:title)).to include("My Faves")

    # Tapping the new row adds the current video.
    playlist = user.playlists.find_by(title: "My Faves")
    within("#playlist-add-list") { click_on("My Faves") }
    expect(page).to have_css(".playlist-add__row.is-added", text: "My Faves")
    expect(playlist.reload.videos).to include(video)
  end

  it "does not create a playlist when the name is blank" do
    open_add_to_playlist
    within("#playlist-add-create") do
      click_button "Add a playlist"
      find("button[aria-label='Create playlist']").click
    end
    expect(user.playlists.reload.pluck(:title)).to eq([ "Videos you liked" ])
  end
end
