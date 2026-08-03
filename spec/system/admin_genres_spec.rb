require 'rails_helper'

RSpec.describe "Admin genre management", type: :system do
  let(:admin) { create(:user, :admin, password: "password123") }

  def sign_in_as(u)
    visit new_session_path
    fill_in "Login", with: u.email_address
    fill_in "Senha", with: "password123"
    click_button "Login"
    expect(page).to have_css("main.home")
  end

  before { sign_in_as(admin) }

  it "reaches genres from the nav" do
    create(:genre, name: "Westerns")
    visit admin_dashboard_path

    find(".admin-header__menu").click
    within(".admin-nav") { click_link "Genres" }

    expect(page).to have_current_path(admin_genres_path)
    expect(page).to have_content("Westerns")
  end

  it "adds a genre through the modal and prepends its row" do
    visit admin_genres_path

    click_link "Add"
    expect(page).to have_css("dialog.modal[open]")
    fill_in "Name", with: "Neo-Noir"
    click_button "Save"

    expect(page).to have_no_css("dialog.modal[open]")
    expect(page).to have_content("Neo-Noir")
    expect(Genre.find_by(name: "Neo-Noir")).to be_present
  end

  it "renames a genre through the modal" do
    genre = create(:genre, name: "Comdey")
    visit admin_genres_path

    within("#admin_genre_row_#{genre.id}") { find(".admin-live__action[aria-label='Edit Comdey']").click }
    expect(page).to have_css("dialog.modal[open]")
    fill_in "Name", with: "Comedy"
    click_button "Save"

    expect(page).to have_no_css("dialog.modal[open]")
    expect(genre.reload.name).to eq("Comedy")
  end

  it "deletes a genre" do
    genre = create(:genre, name: "Removable")
    visit admin_genres_path

    accept_confirm do
      within("#admin_genre_row_#{genre.id}") { find(".admin-live__action--danger").click }
    end

    expect(page).to have_no_content("Removable")
    expect(Genre.exists?(genre.id)).to be(false)
  end

  it "opens a genre's detail page" do
    genre = create(:genre, name: "Adventure")
    movie = create(:movie, title: "An Adventure Movie")
    create(:tagging, genre: genre, taggable: movie)
    visit admin_genres_path

    within("#admin_genre_row_#{genre.id}") { find(".admin-live__action[aria-label='View Adventure']").click }

    expect(page).to have_current_path(admin_genre_path(genre))
    expect(page).to have_content("An Adventure Movie")
  end
end
