require 'rails_helper'

# Player keyboard shortcuts (F = fullscreen, Space = play/pause) must NOT fire
# while the viewer is typing in the comment/reply fields on the player page.
# The positive play/pause + fullscreen paths are verified live via Playwright
# (they depend on real media decode, which is unreliable under headless Selenium).
RSpec.describe "Player keyboard shortcuts", type: :system do
  let(:user) { create(:user, password: "password123") }
  let(:video) { create(:video, :with_thumbnail, :with_file, title: "Keyed Clip", visibility: :public) }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(user) }

  it "types Space and F normally in the comment field without toggling the player" do
    visit player_path(video.slug)
    expect(page).to have_css("main.player")

    field = find("textarea[name='comment[body]']")
    field.click
    field.send_keys("a", :space, "f", "n")

    expect(field.value).to eq("a fn")
    # Neither shortcut fired: video never started and fullscreen never engaged.
    expect(page).to have_no_css(".player.is-playing")
    expect(page.evaluate_script("!!document.fullscreenElement")).to be(false)
  end
end
