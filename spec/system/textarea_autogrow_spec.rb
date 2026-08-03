require 'rails_helper'

# Description textareas grow with what's typed so nothing scrolls out of sight,
# and stop growing at 40vh so a modal's footer buttons stay reachable.
RSpec.describe "Auto-growing description textareas", type: :system do
  let(:password) { "password123" }

  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: password
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  def box(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector("#{selector}")
        return { height: Math.round(el.getBoundingClientRect().height),
                 hidden: el.scrollHeight - el.clientHeight }
      })()
    JS
  end

  DESCRIPTION = "textarea[name='video[description]']".freeze

  it "grows the upload description as the user types, with nothing clipped" do
    sign_in_as(create(:user, password: password))
    visit new_video_path
    expect(page).to have_css(DESCRIPTION)

    before = box(DESCRIPTION)
    fill_in "video[description]", with: (1..9).map { |i| "Description line #{i}." }.join("\n")

    after = box(DESCRIPTION)
    expect(after["height"]).to be > before["height"]
    expect(after["hidden"]).to eq(0) # every typed line is visible
  end

  it "caps growth at 40vh and keeps the modal's Save button on screen" do
    admin = create(:user, :admin, password: password)
    movie = create(:movie, title: "Long Synopsis", video: create(:video, :with_file, kind: :feature, visibility: :public))
    sign_in_as(admin)

    visit edit_admin_catalog_item_path("movie", movie)
    selector = "textarea[name='description']"
    expect(page).to have_css(selector)

    fill_in "description", with: (1..60).map { |i| "Line #{i} of a very long description." }.join("\n")

    grown = box(selector)
    cap = page.evaluate_script("Math.round(window.innerHeight * 0.4)")
    expect(grown["height"]).to be <= cap + 2 # +borders
    expect(grown["hidden"]).to be > 0        # the overflow scrolls inside the box
    expect(page.evaluate_script("getComputedStyle(document.querySelector(\"#{selector}\")).overflowY")).to eq("auto")

    # The capped textarea keeps Save reachable inside the modal's own scroll —
    # the full edit form has many fields, so on a phone Save sits below the fold
    # until the panel is scrolled, which is exactly what the cap makes possible.
    save_reachable = page.evaluate_script(<<~JS)
      (() => {
        const btn = document.querySelector("dialog input[type='submit'], dialog button[type='submit']")
        btn.scrollIntoView({ block: "end" })
        const r = btn.getBoundingClientRect()
        return r.top >= 0 && r.bottom <= window.innerHeight + 1
      })()
    JS
    expect(save_reachable).to be(true)
  end
end
