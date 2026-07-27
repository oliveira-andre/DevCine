Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create]
  resources :passwords, param: :token

  get "search", to: "search#index"
  resources :videos, only: %i[index new create]
  resources :movies, only: :index
  get "series", to: "series#index", as: :series
  get "series/:slug", to: "series#show", as: :serie
  get "series/:slug/seasons/:position", to: "series#season", as: :serie_season
  resources :playlists, only: %i[show new create destroy]
  get "lives", to: "lives#index"
  get "genres/:slug", to: "catalog/browse#show", as: :genre_browse
  get "kinds/:kind", to: "catalog/browse#show", as: :kind_browse

  get "account/edit", to: "profiles#edit", as: :edit_account
  get "account/name/edit", to: "profiles#edit_name", as: :edit_name_account
  patch "account/name", to: "profiles#update_name", as: :name_account
  get "account", to: "accounts#show", as: :account
  patch "account", to: "profiles#update", as: :update_account
  get "account/:slug", to: "accounts#show", as: :public_account
  namespace :settings do
    resource :password, only: %i[edit update]
    resource :pin, only: %i[show create] do
      post :unlock
    end
  end

  namespace :admin do
    get "dashboard", to: "dashboard#show"
    resources :lives # manage embed-based live videos (009)
  end

  get  "playing/:slug",          to: "player#show",        as: :player
  get  "playing/:slug/related",  to: "player#related",     as: :player_related
  post "playing/:slug/views",    to: "video_views#create", as: :player_views
  post "playing/:slug/progress", to: "watch_progresses#create", as: :player_progress
  get  "playing/:slug/comments", to: "comments#index",     as: :player_comments
  post "playing/:slug/comments", to: "comments#create"

  post "reactions/:type/:id", to: "reactions#create", as: :reactions

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
