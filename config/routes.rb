Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create]
  resources :passwords, param: :token

  # Search entry page + section listing pages + category browse (feature 003).
  get "search", to: "search#index"
  resources :videos, only: %i[index new create] # new/create = standalone upload modal (004)
  resources :movies, only: :index
  get "series", to: "series#index", as: :series # "series" is uncountable → force series_path
  get "lives", to: "lives#index"
  get "genres/:slug", to: "catalog/browse#show", as: :genre_browse
  get "kinds/:kind", to: "catalog/browse#show", as: :kind_browse

  # Account profile + modals (004). Order matters: specific routes before :slug.
  get "account/edit", to: "profiles#edit", as: :edit_account
  get "account/name/edit", to: "profiles#edit_name", as: :edit_name_account
  patch "account/name", to: "profiles#update_name", as: :name_account
  get "account", to: "accounts#show", as: :account
  patch "account", to: "profiles#update", as: :update_account
  get "account/:slug", to: "accounts#show", as: :public_account
  namespace :settings do
    resource :password, only: %i[edit update]
    # PIN for restricted content (006): modal (show), first-time setup (create),
    # and unlock verification.
    resource :pin, only: %i[show create] do
      post :unlock
    end
  end

  # Admin-only area (guarded by Admin::BaseController#require_admin).
  namespace :admin do
    get "dashboard", to: "dashboard#show"
  end

  # Video player (feature 005). :slug is the video's FriendlyId. The related and
  # comments#index endpoints are the src of lazy-loaded Turbo Frames (FR-028).
  get  "playing/:slug",          to: "player#show",        as: :player
  get  "playing/:slug/related",  to: "player#related",     as: :player_related
  post "playing/:slug/views",    to: "video_views#create", as: :player_views
  post "playing/:slug/progress", to: "watch_progresses#create", as: :player_progress
  get  "playing/:slug/comments", to: "comments#index",     as: :player_comments
  post "playing/:slug/comments", to: "comments#create"

  # Like/dislike reactions on a video or comment (feature 005 enhancement).
  post "reactions/:type/:id", to: "reactions#create", as: :reactions

  # Add-to-playlist modal (feature 005 enhancement).
  get  "playing/:slug/add-to-playlist", to: "playlist_additions#new", as: :add_to_playlist
  post "playlists/:playlist_id/toggle/:slug", to: "playlist_additions#create", as: :toggle_playlist_video
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
