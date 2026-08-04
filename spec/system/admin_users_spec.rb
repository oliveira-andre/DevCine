require 'rails_helper'

RSpec.describe "Admin user management", type: :system do
  let(:admin) { create(:user, :admin, password: "password123") }
  let!(:member) do
    create(:user, password: "password123", email_address: "member@example.com",
                  display_name: "Member One")
  end

  def sign_in_as(u)
    visit new_session_path
    fill_in "Email", with: u.email_address
    fill_in "Password", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(admin) }

  it "reaches users from the admin sidebar" do
    visit admin_dashboard_path

    # Mobile viewport: the nav is a drawer opened from the header menu button.
    find(".admin-header__menu").click
    within(".admin-nav") { click_link "Users" }

    expect(page).to have_current_path(admin_users_path)
    expect(page).to have_content("member@example.com")
  end

  it "finds a user by email" do
    create(:user, email_address: "unrelated@example.com")
    visit admin_users_path

    fill_in "q", with: "member@"

    # Wait for Turbo to advance the URL — that only happens once the frame swap
    # is committed.
    expect(page).to have_current_path(admin_users_path(q: "member@"))
    expect(page).to have_content("member@example.com")
    expect(page).to have_no_content("unrelated@example.com")
    expect(page).to have_css("a[aria-label='View member@example.com'][href='#{admin_user_path(member)}']")
  end

  # Deliberately NOT chained onto the search above: a click landing in the
  # moment the debounced search swaps the list frame can be swallowed, so
  # asserting navigation right after typing tests a guarantee the UI does not
  # actually make.
  it "opens a user's detail page from the list" do
    visit admin_users_path

    find("a[aria-label='View member@example.com']").click

    expect(page).to have_current_path(admin_user_path(member))
    expect(page).to have_content("member@example.com")
    expect(page).to have_content("Member One")
  end

  it "follows a see-all link through to the full activity list" do
    create(:comment, user: member, body: "A remark worth reading")
    visit admin_user_path(member)

    expect(page).to have_content("A remark worth reading")
    within("#admin_user_section_comments") { click_link "See all (1)" }

    expect(page).to have_current_path(comments_admin_user_path(member))
    expect(page).to have_content("A remark worth reading")
  end

  it "edits a user's name and role in the modal and refreshes the detail card" do
    visit admin_user_path(member)

    click_link "Edit user"
    expect(page).to have_css("dialog.modal")

    fill_in "Display name", with: "Renamed Member"
    select "Blocked", from: "Role"
    click_button "Save"

    expect(page).to have_no_css("dialog.modal")
    within("#admin_user_detail") do
      expect(page).to have_content("Renamed Member")
      expect(page).to have_content("Blocked")
    end
    expect(member.reload).to be_blocked
  end

  it "changes a password from the modal without the current one" do
    visit admin_user_path(member)
    click_link "Edit user"

    fill_in "New password", with: "a-fresh-password"
    fill_in "Confirm new password", with: "a-fresh-password"
    click_button "Save"

    expect(page).to have_no_css("dialog.modal")
    expect(member.reload.authenticate("a-fresh-password")).to be_truthy
  end

  it "expands a video row to reveal its details" do
    create(:video, :with_thumbnail, uploader: member, title: "Detailed Upload",
                   visibility: :public, description: "A description worth reading.")
    visit uploads_admin_user_path(member)

    # Collapsed: the panel exists but is not shown.
    expect(page).to have_content("Detailed Upload")
    expect(page).to have_no_content("A description worth reading.")

    find(".admin-item__summary", text: "Detailed Upload").click

    expect(page).to have_content("A description worth reading.")
    within(".admin-item__meta") do
      expect(page).to have_content("0 likes")
      expect(page).to have_content("views")
    end
  end

  it "expands a playlist row to reveal its member videos" do
    playlist = create(:playlist, user: member, title: "Expandable Mix")
    create(:playlist_item, playlist: playlist,
                           video: create(:video, title: "Member Track", visibility: :public))
    visit playlists_admin_user_path(member)

    expect(page).to have_no_content("Member Track")

    find(".admin-item__summary", text: "Expandable Mix").click

    expect(page).to have_content("Member Track")
  end

  it "will not let an admin change their own role" do
    visit admin_user_path(admin)

    click_link "Edit user"

    expect(page).to have_content("You cannot change your own role")
    expect(page).to have_css("select[name='user[role]'][disabled]")
  end
end
