Rails.application.routes.draw do
  get 'welcome/index'
  post 'welcome/new_daily'

  resources :dailies
  resources :rates

  root 'welcome#index'
end
