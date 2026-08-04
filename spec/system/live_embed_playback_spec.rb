require 'rails_helper'

# US2: a viewer watches a live as an embedded player.
RSpec.describe "Live embed playback", type: :system do
  let(:user) { create(:user, password: "password123") }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(user) }

  it "renders the embed iframe with the stored URL" do
    live = create(:video, :live, :with_thumbnail, title: "Live Concert", visibility: :public)
    visit player_path(live.slug)
    frame = find("iframe.live-embed__frame")
    expect(frame[:src]).to eq(live.live_embed_url)
    # A live is not handed to the persistent file player (feature 010).
    expect(page).to have_no_css("[data-controller='player-source']")
  end

  it "shows the unavailable state when the embed URL is blank" do
    live = create(:video, :live, visibility: :public)
    live.update_column(:live_embed_url, nil)
    visit player_path(live.slug)
    expect(page).to have_content("not available yet")
    expect(page).to have_no_css("iframe.live-embed__frame")
  end
end
