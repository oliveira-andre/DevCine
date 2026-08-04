require 'rails_helper'

# US2: create a playlist from the account page via the modal.
RSpec.describe "Playlist create modal (account)", type: :system do
  let(:user) { create(:user, password: "password123") }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(user) }

  it "creates a playlist via the modal and appends it to the rail" do
    visit account_path
    within(".rail", text: "Playlists") { find(".rail__add").click }
    expect(page).to have_css("dialog.modal[open]")

    fill_in "Playlist name", with: "Road Trip"
    click_button "Create"

    expect(page).to have_no_css("dialog.modal[open]")
    within("#account_playlists") { expect(page).to have_content("Road Trip") }
    expect(user.playlists.reload.pluck(:title)).to include("Road Trip")
  end

  it "cancels without creating" do
    visit account_path
    within(".rail", text: "Playlists") { find(".rail__add").click }
    expect(page).to have_css("dialog.modal[open]")
    click_button "Cancel"
    expect(page).to have_no_css("dialog.modal[open]")
    expect(user.playlists.reload.pluck(:title)).to eq([ "Videos you liked" ])
  end

  it "shows the create button even with no visible playlists" do
    visit account_path
    expect(page).to have_css(".rail__add")
  end

  it "hides the create button on another user's account" do
    other = create(:user, handle: "someone")
    visit public_account_path(other.handle)
    expect(page).to have_no_css(".rail__add")
  end
end
