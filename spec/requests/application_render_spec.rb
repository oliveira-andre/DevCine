require 'rails_helper'

# Feature 010 (spotsby-model refactor): in-app links opt into turbo_stream
# navigation; default_render answers by updating the #page-content div, leaving
# the sibling mini-player untouched. Plain HTML requests render the full layout.
RSpec.describe "Stream-navigation shell", type: :request do
  let(:member) { create(:user, password: "password123") }

  def sign_in
    post session_path, params: { email_address: member.email_address, password: "password123" }
    get root_path # follow the redirect, consuming the auth _full_render flash
  end

  it "renders the full layout with #page-content and the sibling mini-player on plain GETs" do
    sign_in
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<div id="page-content">')
    expect(response.body).to match(/id="mini-player"[^>]*data-turbo-permanent/)
  end

  it "answers stream-negotiated navigation with a page-content update (no layout)" do
    sign_in
    get movies_path, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include('<turbo-stream action="update" target="page-content">')
    # the layout (and thus the mini-player) is NOT re-rendered
    expect(response.body).not_to include('id="mini-player"')
  end

  # Flash banners are a body-level toast stack, not part of the page body: in the
  # flow they occupied a strip of page background that read as part of the header.
  it "renders the toast stack as a body-level sibling of #page-content" do
    sign_in
    get root_path
    doc = Nokogiri::HTML(response.body)
    expect(doc.at("#flash")).to be_present
    expect(doc.at("#flash").parent.name).to eq("body")
    expect(doc.at("#page-content #flash")).to be_nil
  end

  it "streams a redirect notice into #flash, never into the page body" do
    admin = create(:user, :admin, password: "password123")
    post session_path, params: { email_address: admin.email_address, password: "password123" }
    get root_path # consume the auth full-render flag

    movie = create(:movie, title: "Bye Movie",
                   video: create(:video, :with_file, kind: :feature, visibility: :public))
    delete admin_catalog_item_path("movie", movie)
    # Turbo follows the redirect keeping the stream Accept header.
    get response.redirect_url, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

    expect(response.body).to include('<turbo-stream action="update" target="flash">')
    flash_stream = response.body[/target="flash">(.*?)<\/turbo-stream>/m, 1].to_s
    expect(flash_stream).to include("“Bye Movie” was deleted successfully.")

    body_stream = response.body[/target="page-content">(.*?)<\/turbo-stream>/m, 1].to_s
    expect(body_stream).not_to include("form-flash")
  end

  # A form inside the modal Turbo frame redirects after save; Turbo follows the
  # redirect keeping BOTH the form's turbo_stream Accept header and the
  # Turbo-Frame header. That follow-up must swap the frame (modal→modal
  # redirect), never inject a second copy of the modal into #page-content.
  it "answers frame-scoped requests with frame HTML, not a page-content stream" do
    admin = create(:user, :admin, password: "password123")
    post session_path, params: { email_address: admin.email_address, password: "password123" }
    video = create(:video, :with_file, visibility: :public)
    get new_admin_video_subtitle_path(video),
        headers: { "Accept" => "text/vnd.turbo-stream.html, text/html",
                   "Turbo-Frame" => "modal" }
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include('<turbo-frame id="modal">')
    expect(response.body).not_to include('target="page-content"')
    # frame-only render: no surrounding layout
    expect(response.body).not_to include('<div id="page-content">')
  end

  it "leaves actions with dedicated turbo_stream templates untouched (comment create)" do
    sign_in
    video = create(:video, :with_file, visibility: :public)
    post comments_player_path(video.slug),
         params: { comment: { body: "Nice one" } },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).not_to include('target="page-content"')
  end

  it "does not render the player for unauthenticated pages" do
    get new_session_path
    expect(response.body).not_to include('id="mini-player"')
  end
end
