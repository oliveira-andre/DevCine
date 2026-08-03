require 'rails_helper'

RSpec.describe "Browsing and saving playlists", type: :system do
  let(:member) { create(:user, password: "password123") }
  let(:owner) { create(:user, display_name: "Ada Lovelace") }
  let!(:source) { create(:playlist, user: owner, title: "Road Trip", visibility: :public) }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(member) }

  it "reaches playlists from the drawer" do
    find("button[aria-label='Open menu']").click
    click_link "Playlists"

    expect(page).to have_current_path(playlists_path)
    expect(page).to have_content("Road Trip")
    expect(page).to have_content("Ada Lovelace")
  end

  it "filters the browse list by title" do
    create(:playlist, title: "Rock Anthems", visibility: :public)
    visit playlists_path

    fill_in "q", with: "road"

    expect(page).to have_content("Road Trip")
    expect(page).to have_no_content("Rock Anthems")
  end

  it "saves somebody else's playlist and lands on the copy" do
    video = create(:video, :with_thumbnail, title: "Opening Track", visibility: :public)
    create(:playlist_item, playlist: source, video: video, position: 1)
    visit playlist_path(source)

    click_button "Save playlist"

    # Wait for the redirect to land before querying — the original and the copy
    # share a title, so the confirmation toast is what distinguishes them.
    expect(page).to have_content("Saved “Road Trip” to your playlists.")

    copy = member.playlists.find_by(cloned_from: source)
    expect(copy).to be_present
    expect(page).to have_current_path(playlist_path(copy))
    expect(copy.videos).to contain_exactly(video)
  end

  it "shows the saved state on a second visit to the original" do
    visit playlist_path(source)
    click_button "Save playlist"

    visit playlist_path(source)

    expect(page).to have_link("Saved")
    expect(page).to have_no_button("Save playlist")
  end

  it "offers no save button on your own playlist" do
    mine = create(:playlist, user: member, title: "My Own Mix", visibility: :public)

    visit playlist_path(mine)

    expect(page).to have_no_button("Save playlist")
  end

  it "finds a public playlist through search" do
    visit search_path

    fill_in "q", with: "Road"
    find(".search-page__form").native.submit

    expect(page).to have_content("Playlists")
    expect(page).to have_content("Road Trip")
  end
end
