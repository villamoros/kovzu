Rails.application.routes.draw do
  root "home#index"

  # Clerk's hosted components are mounted on these pages
  get "sign-in(/*rest)", to: "sessions#sign_in", as: :sign_in
  get "sign-up(/*rest)", to: "sessions#sign_up", as: :sign_up

  get "dashboard", to: "dashboard#show", as: :dashboard

  # Living catalog of the KOVZU design system (development only)
  get "design", to: "design_system#show", as: :design if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
