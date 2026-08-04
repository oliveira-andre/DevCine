require 'rails_helper'

RSpec.describe "Admin dashboard", type: :system do
  let(:admin) { create(:user, :admin, password: "password123") }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(admin) }

  it "shows the summary counts alongside the recent tables" do
    member = create(:user, email_address: "dash.member@example.com")
    create(:video, title: "Dash Clip", visibility: :public, uploader: member)
    create(:movie, title: "Dash Movie")
    create(:playlist, user: member, title: "Dash Mix")

    visit admin_dashboard_path

    expect(page).to have_css(".admin-stat", minimum: 4)

    %w[members videos movies playlists].each_with_index do |_area, i|
      expect(page).to have_css(".admin-table", minimum: i + 1)
    end

    expect(page).to have_content("dash.member@example.com")
    expect(page).to have_content("Dash Clip")
    expect(page).to have_content("Dash Movie")
    expect(page).to have_content("Dash Mix")
  end

  it "follows a member row through to their admin detail page" do
    member = create(:user, email_address: "dash.link@example.com")

    visit admin_dashboard_path
    # The member also owns an auto-created "Videos you liked" playlist, so their
    # email appears in the playlists table too — scope to the members table.
    within("#admin_recent_members") { click_link "dash.link@example.com" }

    expect(page).to have_current_path(admin_user_path(member))
  end

  # Tables cannot reflow on a phone, so they scroll inside their own box rather
  # than widening the page (Constitution III: mobile-first).
  it "scrolls a wide table inside its own box instead of the page" do
    create(:playlist, user: create(:user), title: "A Playlist With A Fairly Long Title")

    visit admin_dashboard_path

    page_overflows = page.evaluate_script(
      "document.documentElement.scrollWidth > window.innerWidth"
    )
    expect(page_overflows).to be(false)

    scroller_scrolls = page.evaluate_script(<<~JS)
      (() => {
        const boxes = [...document.querySelectorAll('.admin-table__scroll')];
        return boxes.every(b => getComputedStyle(b).overflowX === 'auto');
      })()
    JS
    expect(scroller_scrolls).to be(true)
  end
end
