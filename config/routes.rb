# frozen_string_literal: true

require 'sidekiq/web'

Rails.application.routes.draw do
  use_doorkeeper do
    # it accepts :authorizations, :tokens, :token_info, :applications and :authorized_applications
    controllers authorizations: 'oauth_applications'
  end
  use_doorkeeper_openid_connect
  get 'admin' => 'admin/dashboard#index', as: :admin_dashboard
  namespace :admin do
    get 'sso_apps', to: 'dashboard#apps'
    resources :api_keys
    resources :groups do
      get :email, to: 'groups#email'
    end
    resources :users do
      post :reset_password, to: 'users#reset_password'
      post :disable_two_factor, to: 'users#disable_two_factor'
      post :resend_welcome_email, to: 'users#resend_welcome_email'
      resources :emails do
        post '/', to: 'emails#create'
        post :resend_confirmation, to: 'emails#resend_confirmation', as: :resend_confirmation
        delete '/', to: 'emails#destroy', as: :emails
        post :confirm, to: 'emails#confirm'
      end
    end
    post 'users/bulk_action', to: 'users#bulk_action'
    resources :custom_userdata_types
    resources :custom_group_data_types
    resources :permissions
    resources :applications do
      post :renew_secret, to: 'applications#renew_secret'
    end
    resources :saml_service_providers
    resources :web_hooks
    resources :audits, only: %i[index show]
    get :settings, to: 'settings#index'
    post :settings, to: 'settings#update'
    # namespace :settings do
    get 'settings/openid_connect', to: 'settings#openid_connect'
    get 'settings/saml', to: 'settings#saml'
    get 'settings/branding', to: 'settings#branding'
    get 'settings/templates', to: 'settings#templates'
    # end

    resources :sessions, only: %i[index destroy]

    get 'jobs', to: 'dashboard#jobs'

    authenticate :user, ->(user) { user.admin? || user.operator? } do
      mount Sidekiq::Web => '/sidekiq'
    end
  end

  namespace :api do
    resources :groups do
      get 'users', to: 'groups#list_users'
      resources :users, only: [] do
        post '/', to: 'groups#add_user'
        delete '/', to: 'groups#remove_user'
      end
    end
    resources :users do
      get 'user_data', to: 'users#user_data'
      match 'user_data', to: 'users#update_user_data', via: %i[put post]
    end
  end

  devise_for :users, controllers: {
    registrations: :registrations,
    sessions: :sessions,
    confirmations: :confirmations
  }

  authenticated do
    root to: 'dashboard#home', as: :authenticated_root
  end

  scope '(:locale)', locale: /en/ do
    devise_scope :user do
      root to: 'sessions#new'
    end
  end

  get 'users/2fa', to: 'users#new_2fa', as: 'new_user_2fa_registration'
  post 'users/2fa', to: 'users#create_2fa', as: 'user_two_factor_auth'
  post 'users/2fa/codes', to: 'users#codes', as: 'user_2fa_codes'
  delete '/users/2fa', to: 'users#disable_2fa'
  # SAMLv2 IdP
  get '/saml/auth' => 'saml_idp#create'
  post '/saml/auth' => 'saml_idp#create'
  get '/saml/metadata' => 'saml_idp#show'
  match '/saml/logout' => 'saml_idp#logout', via: %i[get post delete]

  get 'auth/basic/:permission_name', to: 'basic_auth#create'

  get 'profile/account', to: 'profile#show'
  namespace :profile do
    get '/', to: 'profile#index', as: :profile
    match '/', to: 'profile#update', via: %i[patch post]
    get 'authentication_devices', to: 'authentication_devices#index'
    get 'account_activity', to: 'account_activity#index'
    resources :emails do
      post 'resend_confirmation', to: 'emails#resend_confirmation', as: :resend_confirmation
    end
    resources :access_tokens
    get :access_grants, to: 'access_grants#index'
    delete :access_grants, to: 'access_grants#revoke'
    delete :revoke_access_grants, to: 'access_grants#revoke_all'
  end
end
