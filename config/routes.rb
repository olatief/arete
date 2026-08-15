Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Presenter (M4). The board is an unauthenticated output device authorized by
  # a signed httponly cookie; the phone endpoints are teacher-authenticated.
  get   "board"       => "boards#show"
  get   "board/state" => "boards#state"    # resync: { page, started, ended }
  patch "board/page"  => "boards#update_page" # keyboard-nav fallback
  patch "board/end"   => "boards#finish"      # Esc recovery when the phone dies

  get "lessons/:lesson_id/teach" => "teach_sessions#new", as: :lesson_teach

  resources :teach_sessions, only: %i[update] do
    post :pair, on: :collection
    member do
      get   :companion
      get   :state
      patch :start
      patch :finish
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#show"
end
