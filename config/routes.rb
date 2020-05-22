Rails.application.routes.draw do
  get 'welcome/index'
  post 'welcome/new_daily'

  resources :dailies

  root 'welcome#index'
end
