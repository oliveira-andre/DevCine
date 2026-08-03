require 'rails_helper'

# Going fullscreen on a handheld should turn the device to landscape.
# Headless Selenium cannot grant a real fullscreen transition (see
# player_shortcuts_spec.rb), so the Fullscreen and Screen Orientation APIs are
# stubbed and the controller's call sequence is asserted instead. The stub
# mirrors its calls onto a data attribute so Capybara waits for the promises
# rather than sleeping.
RSpec.describe "Player fullscreen orientation", type: :system do
  let(:user) { create(:user, password: "password123") }
  let(:video) { create(:video, :with_thumbnail, :with_file, title: "Landscape Clip", visibility: :public) }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  # `lock_result`: "resolve" mimics Android Chrome, "reject" mimics desktop and
  # iOS Safari, where locking is not supported.
  def stub_orientation_api(lock_result: "resolve")
    page.execute_script(<<~JS)
      window.__calls = [];
      window.__record = (c) => {
        window.__calls.push(c);
        document.body.dataset.fsCalls = window.__calls.join(",");
      };
      const mp = document.querySelector("#mini-player");
      mp.requestFullscreen = () => { window.__record("requestFullscreen"); return Promise.resolve(); };
      if (!screen.orientation) {
        Object.defineProperty(screen, "orientation", { value: {}, configurable: true });
      }
      screen.orientation.lock = (o) => {
        window.__record("lock:" + o);
        return #{lock_result == 'reject' ? 'Promise.reject(new Error("unsupported"))' : 'Promise.resolve()'};
      };
      screen.orientation.unlock = () => window.__record("unlock");
      window.addEventListener("unhandledrejection", () => window.__record("UNHANDLED"));
    JS
  end

  def click_fullscreen
    # Clicked via script: the button is pointer-events:none until the player
    # chrome is active, and chrome activation is not what this spec covers.
    page.execute_script(%{document.querySelector('[data-action="mini-player#toggleFullscreen"]').click()})
  end

  before do
    sign_in_as(user)
    visit player_path(video.slug)
    expect(page).to have_css("main.player")
    expect(page).to have_css("#mini-player")
  end

  it "locks the screen to landscape after entering fullscreen" do
    stub_orientation_api

    click_fullscreen

    expect(page).to have_css("body[data-fs-calls='requestFullscreen,lock:landscape']")
  end

  it "releases the lock when fullscreen exits" do
    stub_orientation_api
    click_fullscreen
    expect(page).to have_css("body[data-fs-calls='requestFullscreen,lock:landscape']")

    page.execute_script(%{document.dispatchEvent(new Event("fullscreenchange"))})

    expect(page).to have_css("body[data-fs-calls='requestFullscreen,lock:landscape,unlock']")
  end

  it "stays silent where orientation locking is unsupported" do
    stub_orientation_api(lock_result: "reject")

    click_fullscreen

    expect(page).to have_css("body[data-fs-calls='requestFullscreen,lock:landscape']")
    # A rejected lock must not surface as an unhandled promise rejection.
    expect(page).to have_no_css("body[data-fs-calls*='UNHANDLED']")
  end
end
