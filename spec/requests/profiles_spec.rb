require 'rails_helper'

RSpec.describe "Profiles", type: :request do
  let(:member) { create(:user, password: "password123") }

  before { post session_path, params: { email_address: member.email_address, password: "password123" } }

  def upload(name, type)
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/#{name}"), type)
  end

  describe "GET /account/edit" do
    it "renders the avatar/cover form" do
      get edit_account_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Profile picture")
      expect(response.body).to include("Cover image")
    end
  end

  describe "PATCH /account" do
    it "attaches a new avatar" do
      patch update_account_path, params: { user: { avatar: upload("sample_image.jpg", "image/jpeg") } }
      expect(member.reload.avatar).to be_attached
    end

    it "rejects a non-image and does not attach it" do
      patch update_account_path, params: { user: { avatar: upload("not_an_image.txt", "text/plain") } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(member.reload.avatar).not_to be_attached
    end
  end

  describe "inline display-name edit" do
    it "renders the inline name form in the account_name frame" do
      get edit_name_account_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("account_name")
      expect(response.body).to include("user[display_name]")
    end

    it "updates the display name" do
      patch name_account_path, params: { user: { display_name: "Renamed Member" } }
      expect(response).to have_http_status(:ok)
      expect(member.reload.display_name).to eq("Renamed Member")
    end
  end
end
