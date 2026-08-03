require 'rails_helper'

RSpec.describe "Admin comment moderation", type: :system do
  let(:admin) { create(:user, :admin, password: "password123") }
  let(:member) { create(:user, display_name: "Ada", email_address: "ada@example.com") }
  let(:video) { create(:video, title: "Commented Film", visibility: :public) }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(admin) }

  it "reaches comments from the nav and lists them" do
    create(:comment, user: member, video: video, body: "a public remark")
    visit admin_dashboard_path

    find(".admin-header__menu").click
    within(".admin-nav") { click_link "Comments" }

    expect(page).to have_current_path(admin_comments_path)
    expect(page).to have_content("a public remark")
  end

  it "filters the list by search" do
    create(:comment, user: member, video: video, body: "keep this one")
    create(:comment, user: member, video: video, body: "hide the other")
    visit admin_comments_path

    fill_in "q", with: "keep this"

    expect(page).to have_content("keep this one")
    expect(page).to have_no_content("hide the other")
  end

  it "opens a thread and shows its replies" do
    thread = create(:comment, user: member, video: video, body: "the original point")
    create(:comment, user: member, video: video, body: "the follow-up", parent: thread)
    visit admin_comments_path

    within("#admin_comment_row_#{thread.id}") { find(".admin-live__action[aria-label='View comment']").click }

    expect(page).to have_current_path(admin_comment_path(thread))
    expect(page).to have_content("the original point")
    expect(page).to have_content("Replies (1)")
    expect(page).to have_content("the follow-up")
  end

  it "deletes a comment from the list, dropping its row" do
    comment = create(:comment, user: member, video: video, body: "delete me from the list")
    visit admin_comments_path

    accept_confirm do
      within("#admin_comment_row_#{comment.id}") { find(".admin-live__action--danger").click }
    end

    expect(page).to have_no_content("delete me from the list")
    expect(Comment.exists?(comment.id)).to be(false)
  end

  it "deletes from the detail page and returns to the list" do
    comment = create(:comment, user: member, video: video, body: "delete from detail")
    visit admin_comment_path(comment)

    accept_confirm { click_button "Delete" }

    expect(page).to have_current_path(admin_comments_path)
    expect(Comment.exists?(comment.id)).to be(false)
  end
end
