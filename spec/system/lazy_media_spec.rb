require 'rails_helper'

RSpec.describe "Lazy media", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "shows a spinner that swaps to the image once it loads" do
    create(:movie, :with_poster)
    sign_in_as(create(:user, password: "password123"))

    # The lazy-image controller marks the wrapper loaded after the image loads.
    expect(page).to have_css(".media.is-loaded .media__img", wait: 5)
  end

  it "shows a placeholder (not a stuck spinner) when there is no image" do
    create(:movie) # no poster attached
    sign_in_as(create(:user, password: "password123"))

    expect(page).to have_css(".media.poster-placeholder", visible: :all)
  end
end
