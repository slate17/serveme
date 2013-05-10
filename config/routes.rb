Serveme::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => "sessions" }

  devise_scope :user do
    get '/sessions/auth/:provider' => 'sessions#passthru'
    post '/users/auth/:provider/callback' => 'sessions#steam'
    get '/users/auth/:provider/callback' => 'sessions#steam'
    delete "/users/logout" => "devise/sessions#destroy"
  end

  resources :sessions do
    collection do
      get :steam
      post :passthru
      get :failure
    end
  end

  resources :users do
    collection do
      get :edit
      post :update
    end
  end


  resources :reservations do
    member do
      post :extend
    end
    collection do
      get :server_selection
      post :time_selection
    end
    resources :log_uploads, :only => [:new, :create, :index] do
      collection do
        get :show_log
      end
    end
  end

  resources :pages do
    collection do
      get :credits
      get :recent_reservations
      get :statistics
      get :servers
      get :server_providers
      get :faq
    end
  end

  get   '/login', :to => 'sessions#new',  :as => :login
  match '/users/auth/failure',            :to => 'sessions#failure'

  root :to => "pages#welcome"
end
