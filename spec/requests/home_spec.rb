require 'rails_helper'

RSpec.describe "Home", type: :request do
  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "password123" }
  end

  describe "GET /" do
    it "redirects an unauthenticated visitor to sign in" do
      get root_path
      expect(response).to redirect_to(new_session_path)
    end

    it "renders for an authenticated member" do
      sign_in(create(:user, password: "password123"))
      get root_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET / content" do
    let(:member) { create(:user, password: "password123") }

    before do
      create_list(:movie, 5)
      create_list(:video, 3, kind: :standalone)
      create_list(:serie, 2)
      sign_in(member)
    end

    it "shows the four rails in the required order" do
      get root_path
      body = response.body

      expect(body).to include("Recently added videos")
      expect(body).to include("Recently added movies")
      expect(body).to include("Recently added series")

      expect(body.index("Recently added videos")).to be < body.index("Recently added movies")
      expect(body.index("Recently added movies")).to be < body.index("Recently added series")
    end

    it "renders a hero of at most four movies" do
      get root_path
      expect(response.body.scan("hero__slide").size).to eq(4)
    end

    it "shows the Last watched rail only when the member has history" do
      get root_path
      expect(response.body).not_to include("Last watched")

      watched = create(:video, kind: :standalone)
      create(:watch_progress, user: member, video: watched)
      get root_path
      expect(response.body).to include("Last watched")
    end
  end
end
