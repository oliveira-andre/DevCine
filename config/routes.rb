Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create]
  resources :passwords, param: :token

  get "search", to: "search#index"
  # `update` finalises a draft: the form saves itself as soon as it has a title
  # and a file, so ffmpeg can work on the real upload before the viewer commits.
  resources :videos, only: %i[index new create update] do
    # Pick one of the ffmpeg-suggested frames as the thumbnail (or decline).
    member do
      get   "thumbnail-suggestions", to: "thumbnail_suggestions#show",   as: :thumbnail_suggestions
      patch "thumbnail-suggestions", to: "thumbnail_suggestions#update"
      delete "thumbnail-suggestions", to: "thumbnail_suggestions#destroy"
    end
  end
  resources :movies, only: :index
  resources :series, only: %i[index show], param: :slug do
    member do
      get "seasons/:position", action: :season, as: :season
    end
  end
  resources :playlists, only: %i[index show new create destroy] do
    # "Save"/"grab"/"clone" are the same action: take a copy of a public
    # playlist under your own account. Its own controller so PlaylistsController
    # keeps its create-vs-clone concerns apart.
    post :save, to: "playlist_clones#create", on: :member
  end
  get "lives", to: "lives#index"
  get "genres/:slug", to: "catalog/browse#show", as: :genre_browse
  get "kinds/:kind", to: "catalog/browse#show", as: :kind_browse

  # The viewer's own account: show is AccountsController, editing is Profiles.
  resource :account, only: :show, controller: "accounts" do
    get   :edit,        to: "profiles#edit"
    patch "/",          to: "profiles#update",      as: :update
    get   "name/edit",  to: "profiles#edit_name",   as: :edit_name
    patch "name",       to: "profiles#update_name", as: :name
  end
  get "account/:slug", to: "accounts#show", as: :public_account
  namespace :settings do
    resource :password, only: %i[edit update]
    resource :autoplay, only: :update
    resource :subtitle, only: :update
    resource :pin, only: %i[show create] do
      post :unlock
    end
  end

  namespace :admin do
    get "dashboard", to: "dashboard#show"
    resources :lives, param: :slug
    # Standalone + catalog video management: search/filter, detail, metadata
    # edit, delete, and the per-video subtitle manager.
    resources :videos, only: %i[index show edit update destroy], param: :slug do
      resources :subtitles, only: %i[new create edit update destroy]
    end

    resources :genres
    resources :comments, only: %i[index show destroy]
    resources :playlists, only: %i[index show destroy]

    # User management. The four member actions are the "see all" pages behind
    # each recent-activity section on the detail page.
    resources :users, only: %i[index show edit update] do
      member do
        get :comments
        get :playlists
        get :likes
        get :uploads
      end
    end

    # Catalog creation wizard (movies / series / anime; vanilla or API-assisted).
    resources :catalog, only: %i[index new create], controller: "catalog" do
      collection do
        get  :start
        get  :vanilla
        get  :search
        post :import
      end
    end
    # A created catalog item is addressed by content type + id (movie uuid /
    # serie slug), so the type rides in the path.
    resources :catalog_items, path: "catalog/:type", controller: "catalog",
              only: %i[show edit update destroy], constraints: { type: /movie|serie/ } do
      member do
        post   :upload
        delete :upload, action: :remove_upload
        # Rename/reposition an episode of a serie item.
        get   "episodes/:episode_id/edit", action: :edit_episode, as: :edit_episode
        patch "episodes/:episode_id",      action: :update_episode, as: :episode
      end
    end
  end

  # The player and everything hanging off the playing video.
  resources :playing, only: :show, controller: "player", param: :slug, as: :player do
    member do
      get  :related
      get  "up-next", action: :up_next, as: :up_next
      get  "subtitles/:id", to: "player/subtitles#show", as: :subtitle, defaults: { format: "vtt" }
      post :views,    to: "video_views#create"
      post :progress, to: "watch_progresses#create"
      get  :comments, to: "comments#index"
      post :comments, to: "comments#create", as: nil
      get  "add-to-playlist", to: "playlist_additions#new", as: :add_to_playlist
    end
  end

  post "reactions/:type/:id", to: "reactions#create", as: :reactions
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
