require 'rails_helper'

# US1/US3/US4: an admin manages lives from the sidebar Lives page.
RSpec.describe "Admin lives management", type: :system do
  let(:admin) { create(:user, :admin, password: "password123") }
  let(:embed) { "https://www.youtube.com/embed/O8bnDdWsk8Q" }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(admin) }

  it "reaches Lives from the sidebar and adds a live via the modal (US1)" do
    visit admin_dashboard_path
    # Mobile viewport: the nav is a drawer opened from the header menu button.
    find(".admin-header__menu").click
    within(".admin-nav") { click_link "Lives" }
    expect(page).to have_current_path(admin_lives_path)

    click_link "Add"
    expect(page).to have_css("dialog.modal[open]")
    fill_in "Title", with: "Championship Final"
    fill_in "Embed link", with: embed
    click_button "Save"

    expect(page).to have_no_css("dialog.modal[open]")
    within("#admin_lives") { expect(page).to have_content("Championship Final") }
    expect(Video.live.where(title: "Championship Final")).to exist
  end

  it "shows a server validation error for a non-https embed URL (US1)" do
    visit admin_lives_path
    click_link "Add"
    fill_in "Title", with: "Bad Embed"
    fill_in "Embed link", with: "http://insecure.example/embed" # valid URL format, non-https
    click_button "Save"
    expect(page).to have_css(".form-flash-alert")
    expect(page).to have_css("dialog.modal[open]")
    expect(Video.live.where(title: "Bad Embed")).not_to exist
  end

  it "edits a live in place via the pencil (US3)" do
    live = create(:video, :live, title: "Before", uploader: admin)
    visit admin_lives_path
    within("#admin_live_row_#{live.id}") { find(".admin-live__action[aria-label^='Edit']").click }
    expect(page).to have_css("dialog.modal[open]")
    fill_in "Title", with: "After"
    click_button "Save"
    within("#admin_live_row_#{live.id}") { expect(page).to have_content("After") }
    expect(live.reload.title).to eq("After")
  end

  it "deletes a live after confirming (US3)" do
    live = create(:video, :live, title: "Ended Stream", uploader: admin)
    visit admin_lives_path
    accept_confirm { within("#admin_live_row_#{live.id}") { find(".admin-live__action--danger").click } }
    expect(page).to have_no_css("#admin_live_row_#{live.id}")
    expect(Video.exists?(live.id)).to be(false)
  end

  it "filters the list by title (US4)" do
    create(:video, :live, title: "Football Final", uploader: admin)
    create(:video, :live, title: "Cooking Show", uploader: admin)
    visit admin_lives_path
    fill_in "q", with: "foot"
    within("#admin_lives") do
      expect(page).to have_content("Football Final")
      expect(page).to have_no_content("Cooking Show")
    end
  end

  it "infinite-scrolls a long list (US4)" do
    25.times { |i| create(:video, :live, title: format("Live %02d", i + 1), uploader: admin) }
    visit admin_lives_path
    expect(page).to have_content("Live 25") # newest first (recent)
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    expect(page).to have_content("Live 01") # oldest appears after the next page loads
  end
end
