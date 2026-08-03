require 'rails_helper'

RSpec.describe "Admin genres", type: :request do
  let(:admin) { create(:user, :admin, password: "password123") }

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  it "turns a non-admin away" do
    sign_in_as(create(:user, password: "password123"))
    get admin_genres_path
    expect(response).to redirect_to(root_path)
  end

  context "as an admin" do
    before { sign_in_as(admin) }

    describe "GET /admin/genres" do
      it "lists genres and searches by name" do
        create(:genre, name: "Documentary")
        create(:genre, name: "Thriller")

        get admin_genres_path
        expect(response.body).to include("Documentary")
        expect(response.body).to include("Thriller")

        get admin_genres_path(q: "docu")
        expect(response.body).to include("Documentary")
        expect(response.body).not_to include("Thriller")
      end

      it "shows how many titles carry each genre" do
        genre = create(:genre, name: "Sci-Fi")
        movie = create(:movie)
        create(:tagging, genre: genre, taggable: movie)

        get admin_genres_path

        expect(response.body).to include("1 title")
      end
    end

    describe "POST /admin/genres" do
      it "creates a genre" do
        expect {
          post admin_genres_path, params: { genre: { name: "Mystery" } }
        }.to change(Genre, :count).by(1)

        expect(Genre.find_by(name: "Mystery")).to be_present
      end

      it "rejects a blank name" do
        post admin_genres_path, params: { genre: { name: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects a duplicate name case-insensitively" do
        create(:genre, name: "Horror")

        expect {
          post admin_genres_path, params: { genre: { name: "horror" } }
        }.not_to change(Genre, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "PATCH /admin/genres/:id" do
      it "renames a genre" do
        genre = create(:genre, name: "Comdey")

        patch admin_genre_path(genre), params: { genre: { name: "Comedy" } }

        expect(genre.reload.name).to eq("Comedy")
      end

      it "rejects an invalid rename" do
        genre = create(:genre, name: "Keepme")

        patch admin_genre_path(genre), params: { genre: { name: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(genre.reload.name).to eq("Keepme")
      end
    end

    describe "GET /admin/genres/:id" do
      it "shows the titles tagged with the genre" do
        genre = create(:genre, name: "Fantasy")
        movie = create(:movie, title: "A Fantasy Movie")
        create(:tagging, genre: genre, taggable: movie)

        get admin_genre_path(genre)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("A Fantasy Movie")
      end
    end

    describe "DELETE /admin/genres/:id" do
      it "deletes the genre and its taggings, keeping the titles" do
        genre = create(:genre, name: "Doomed")
        movie = create(:movie)
        create(:tagging, genre: genre, taggable: movie)

        expect {
          delete admin_genre_path(genre)
        }.to change(Genre, :count).by(-1).and change(Tagging, :count).by(-1)

        expect(Movie.exists?(movie.id)).to be(true)
      end
    end
  end
end
