require 'rails_helper'

# Admin catalog wizard (system): modal steps for the vanilla flow.
RSpec.describe "Admin catalog wizard", type: :system do
  let(:admin) { create(:user, :admin, password: "password123") }

  before do
    visit new_session_path
    fill_in "Login", with: admin.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  it "creates a serie manually through the modal wizard and shows upload slots" do
    visit admin_catalog_index_path
    find(".admin__add").click

    # Step 1: type + mode
    within(".modal__form") do
      choose "TV show"
      choose "Enter everything manually"
      click_button "Continue"
    end

    # Step 2: vanilla form
    expect(page).to have_content("New TV show")
    fill_in "Name", with: "Garage Chronicles"
    fill_in "How many seasons?", with: 2
    click_button "Create"

    # Lands on the upload page with both seasons and add-episode dropzones.
    expect(page).to have_content("Garage Chronicles")
    expect(page).to have_content("was created successfully") # flash banner
    expect(page).to have_content("Season 1")
    expect(page).to have_content("Season 2")
    expect(page).to have_css(".dropzone", count: 2) # one add-episode zone per season
    expect(Serie.friendly.find("garage-chronicles").seasons.count).to eq(2)
  end

  it "uploads through the dropzone end-to-end (multipart) and shows the file afterwards" do
    serie = CatalogImport.vanilla!(kind: "serie", title: "Zone Show", seasons_count: 1, uploader: admin)
    season = serie.seasons.first
    placeholder = Video.create!(title: "Zone Show S1E1", kind: :episode, status: :uploading,
                                visibility: :private, uploader: admin)
    season.episodes.create!(video: placeholder, title: "Episode 1", position: 1)

    visit admin_catalog_item_path("serie", serie)
    expect(page).to have_css(".dropzone", count: 2) # placeholder slot + add-episode

    # Feed the hidden input directly — fires change → dropzone auto-submits.
    attach_file "file", Rails.root.join("spec/fixtures/files/sample_image.jpg"),
                make_visible: true, match: :first

    expect(page).to have_content("was saved successfully") # flash banner
    expect(page).to have_css(".admin-badge", text: "Uploaded")
    expect(page).to have_content("sample_image.jpg")          # filename shown
    expect(page).to have_css("a[href*='disposition=attachment']") # download link
    expect(placeholder.reload.file).to be_attached
  end

  it "offers the API search step for anime" do
    allow(CatalogLookup).to receive(:search).and_return([])
    visit admin_catalog_index_path
    find(".admin__add").click

    within(".modal__form") do
      choose "Anime"
      choose "Look it up (TMDB / AniList / TVmaze)"
      click_button "Continue"
    end

    expect(page).to have_content("Find anime")
    within("turbo-frame#modal") do
      fill_in "Name", with: "Nothingness"
      click_button "Search"
    end
    expect(page).to have_content("Nothing found")
  end
end
