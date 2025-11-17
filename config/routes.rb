Rails.application.routes.draw do
  get 'forecasts/new'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root 'forecasts#new'

  resources :forecasts, only: %i[new create]

  # Redirect /forecasts to the form.
  # This prevents errors if a user refreshes the page while on /forecasts.
  get '/forecasts', to: redirect('/forecasts/new')
end
