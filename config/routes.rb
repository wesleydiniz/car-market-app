Rails.application.routes.draw do
  get '/cars/recommended', to: 'cars#recommended'
end