require 'rails_helper'

# Feature 011: the catalog controls row (genre pills on movies/series, ordering
# pill everywhere) driven by Turbo Drive navigation.
RSpec.describe "Catalog controls", type: :system do
  let(:user) { create(:user, password: "password123") }

  let!(:action) { Genre.find_or_create_by!(name: "Action") }
  let!(:apple) { movie("Apple Movie", 2.hours.ago, genre: action) }
  let!(:zebra) { movie("Zebra Movie", 1.hour.ago) }

  def movie(title, created, genre: nil)
    v = create(:video, :with_thumbnail, kind: :feature, visibility: :public, created_at: created)
    m = create(:movie, title: title, video: v, created_at: created)
    create(:tagging, genre: genre, taggable: m) if genre
    m
  end

  before do
    Ordering.find_or_create_by!(label: "A-Z") { |o| o.field = "title"; o.direction = "asc"; o.position = 2 }
    Ordering.where(default: true).update_all(default: false)
    Ordering.bump_version(Ordering::CACHE_SCOPE)
    visit new_session_path
    fill_in "Login", with: user.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "shows genre pills + ordering pill on Movies and filters by genre" do
    visit movies_path
    within(".catalog-controls__genres") do
      expect(page).to have_link("All")
      expect(page).to have_link("Action")
    end
    expect(page).to have_css(".catalog-controls__sort")

    click_link "Action"
    expect(page).to have_current_path(/genre=action/)
    expect(page).to have_content("Apple Movie")
    expect(page).to have_no_content("Zebra Movie")
  end

  it "opens the ordering menu and re-sorts" do
    visit movies_path
    within(".catalog-controls__sort") do
      expect(page).to have_button(text: /most recent/)
      find(".pill--sort").click
      expect(page).to have_link("A-Z")
      click_link "A-Z"
    end
    expect(page).to have_current_path(/sort=a-z/)
  end

  # Regression: the menu carries the `hidden` attribute, but the panel's own
  # `display: flex` beat the UA's `[hidden] { display: none }` (author rules win
  # over UA rules regardless of specificity), so it sat open on every listing.
  it "keeps the ordering menu closed until the sort pill is clicked" do
    visit movies_path

    expect(page).to have_no_css(".catalog-controls__menu", visible: :visible)

    find(".pill--sort").click
    expect(page).to have_css(".catalog-controls__menu", visible: :visible)

    find(".pill--sort").click
    expect(page).to have_no_css(".catalog-controls__menu", visible: :visible)
  end

  it "shows the ordering pill but NO genre pills on Videos" do
    create(:video, :with_thumbnail, :with_file, kind: :standalone, visibility: :public, title: "A Clip")
    visit videos_path
    expect(page).to have_css(".catalog-controls__sort")
    expect(page).to have_no_css(".catalog-controls__genres")
  end
end
