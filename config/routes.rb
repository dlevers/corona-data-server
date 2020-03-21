Rails.application.routes.draw do
  get 'welcome/index'

  resources :dailies

  root 'welcome#index'
end
