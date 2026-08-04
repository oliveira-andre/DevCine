require 'rails_helper'

RSpec.describe "Admin playlist management", type: :system do
  let(:admin) { create(:user, :admin, password: "password123") }
  let(:owner) { create(:user, email_address: "owner@example.com") }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(admin) }

  it "opens a playlist's detail page listing its videos in order" do
    playlist = create(:playlist, user: owner, title: "Roadtrip", visibility: :public)
    create(:playlist_item, playlist: playlist, position: 1,
                           video: create(:video, :with_thumbnail, title: "Opening Track", visibility: :public))
    create(:playlist_item, playlist: playlist, position: 2,
                           video: create(:video, :with_thumbnail, title: "Closing Track", visibility: :public))
    visit admin_playlists_path

    within("#admin_playlist_row_#{playlist.id}") { find(".admin-live__action[aria-label='View Roadtrip']").click }

    expect(page).to have_current_path(admin_playlist_path(playlist))
    expect(page).to have_content("Videos (2)")
    expect(page).to have_content("Opening Track")
    expect(page).to have_content("Closing Track")
    expect(page).to have_content("owner@example.com")
  end

  it "deletes a playlist from its detail page and returns to the list" do
    playlist = create(:playlist, user: owner, title: "Doomed Mix", visibility: :public)
    visit admin_playlist_path(playlist)

    accept_confirm { click_button "Delete" }

    expect(page).to have_current_path(admin_playlists_path)
    expect(Playlist.exists?(playlist.id)).to be(false)
  end
end
