Rails.application.routes.draw do
    root 'landing#index'

    #resources :track
    get 'track/list/:listid', to: 'track#list'

end
