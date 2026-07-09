require 'rails_helper'

RSpec.describe "Home screen", type: :system do
  def sign_in_as(user)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    # Wait for the Turbo navigation to the authenticated home to settle.
    expect(page).to have_css("main.home")
  end

  it "shows the hero and category rails in the required order" do
    user = create(:user, password: "password123")
    create_list(:movie, 5)
    create_list(:video, 3, kind: :standalone)
    create_list(:serie, 2)

    sign_in_as(user)

    expect(page).to have_current_path(root_path)
    # Only the active slide is visible (others are opacity:0), so count all.
    expect(page).to have_css(".hero__slide", count: 4, visible: :all)

    titles = page.all(".rail__title").map(&:text)
    expect(titles).to eq([ "Recently added videos", "Recently added movies", "Recently added series" ])
  end

  it "puts the Last watched rail first when the member has watch history" do
    user = create(:user, password: "password123")
    watched = create(:video, kind: :standalone)
    create(:watch_progress, user: user, video: watched)
    create_list(:movie, 2)

    sign_in_as(user)

    expect(page.all(".rail__title").map(&:text).first).to eq("Last watched")
  end

  it "renders poster cards inside a horizontally scrollable track" do
    user = create(:user, password: "password123")
    create_list(:video, 4, kind: :standalone)

    sign_in_as(user)

    expect(page).to have_css(".rail__track .poster-card", minimum: 4)
    overflow = page.evaluate_script(
      "getComputedStyle(document.querySelector('.rail__track')).overflowX"
    )
    expect(overflow).to eq("auto")
  end
end
