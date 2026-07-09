Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create]
  resources :passwords, param: :token

  # Search entry page + section listing pages + category browse (feature 003).
  get "search", to: "search#index"
  resources :videos, only: :index
  resources :movies, only: :index
  get "series", to: "series#index", as: :series # "series" is uncountable → force series_path
  get "lives", to: "lives#index"
  get "genres/:slug", to: "catalog/browse#show", as: :genre_browse
  get "kinds/:kind", to: "catalog/browse#show", as: :kind_browse
  get "account", to: "accounts#show"
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
