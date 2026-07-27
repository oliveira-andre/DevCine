require 'rails_helper'

# Deleting a playlist from the account card and the player popover (feature 008
# delete): confirm prompt, remove from the list, keep the videos.
RSpec.describe "Playlist delete", type: :system do
  let(:user) { create(:user, password: "password123") }
  let(:video) { create(:video, :with_thumbnail, title: "Keep Me", visibility: :public) }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(user) }

  it "deletes a playlist from the account card after confirming (videos kept)" do
    playlist = create(:playlist, user: user, title: "Trip")
    create(:playlist_item, playlist: playlist, video: video, position: 1)

    visit account_path
    expect(page).to have_css("#playlist_card_#{playlist.id}")

    accept_confirm { within("#playlist_card_#{playlist.id}") { find(".playlist-card__delete").click } }

    expect(page).to have_no_css("#playlist_card_#{playlist.id}")
    expect(Playlist.exists?(playlist.id)).to be(false)
    expect(Video.exists?(video.id)).to be(true) # video kept
  end

  it "does not show a delete control for the auto 'Videos you liked' card" do
    visit account_path
    liked = user.liked_playlist
    # The liked playlist card (if shown) has no delete button.
    if page.has_css?("#playlist_card_#{liked.id}")
      within("#playlist_card_#{liked.id}") { expect(page).to have_no_css(".playlist-card__delete") }
    end
  end

  it "deletes a playlist from the player add-to-playlist popover" do
    playlist = create(:playlist, user: user, title: "Popover List")

    visit player_path(video.slug)
    find("button[aria-label='More options']").click
    click_link "Add to playlist"
    expect(page).to have_css("#playlist_row_#{playlist.id}")

    accept_confirm { within("#playlist_row_#{playlist.id}") { find(".playlist-add__delete").click } }

    expect(page).to have_no_css("#playlist_row_#{playlist.id}")
    expect(Playlist.exists?(playlist.id)).to be(false)
  end
end
