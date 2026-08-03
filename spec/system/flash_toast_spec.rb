require 'rails_helper'

# Flash messages are toasts: a fixed, body-level stack floating over the page
# (in the flow they sat in a strip of page background that read as part of the
# header), self-dismissing so they don't cover content indefinitely.
RSpec.describe "Flash toasts", type: :system do
  let(:admin) { create(:user, :admin, password: "password123") }
  let(:movie) do
    create(:movie, title: "Toast Movie",
           video: create(:video, :with_file, kind: :feature, visibility: :public))
  end

  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "floats below the header, clears the page flow, and fades out on its own" do
    sign_in_as(admin)
    visit edit_admin_catalog_item_path("movie", movie)
    fill_in "title", with: "Toast Movie Renamed"
    click_button "Save"

    expect(page).to have_css("#flash .form-flash", text: "was saved successfully")

    placement = page.evaluate_script(<<~JS)
      (() => {
        const stack = document.getElementById("flash")
        const toast = stack.querySelector(".form-flash")
        // Admin pages carry the admin header, not the app's site-header.
        const header = document.querySelector(".admin-header, .site-header").getBoundingClientRect()
        const r = toast.getBoundingClientRect()
        return {
          parent: stack.parentElement.tagName,
          position: getComputedStyle(stack).position,
          clicksPassThrough: getComputedStyle(stack).pointerEvents,
          belowHeader: r.top >= header.bottom,
          inPageContent: !!document.querySelector("#page-content .form-flash")
        }
      })()
    JS

    expect(placement).to include(
      "parent" => "BODY", "position" => "fixed",
      "clicksPassThrough" => "none", "belowHeader" => true, "inPageContent" => false
    )

    # auto-dismiss (6s) + leave transition
    expect(page).to have_no_css("#flash .form-flash", wait: 9)
  end
end
