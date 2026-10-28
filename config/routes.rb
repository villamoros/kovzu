Rails.application.routes.draw do
  root "home#index"

  # Clerk's hosted components are mounted on these pages
  get "sign-in(/*rest)", to: "sessions#sign_in", as: :sign_in
  get "sign-up(/*rest)", to: "sessions#sign_up", as: :sign_up

  get "dashboard", to: "dashboard#show", as: :dashboard

  # Portal del cliente (paso 3).
  scope module: :portal do
    resource :company, path: "empresa", only: %i[new create]
    resources :requirements, path: "requerimientos", only: %i[index new create show] do
      post :answer, on: :member, path: "respuesta"
    end
    resources :orders, path: "pedidos", only: %i[index show] do
      resource :proposal, path: "propuesta", only: :show do
        post :accept, path: "aceptar"
        post :request_changes, path: "cambios"
      end
    end
    resources :samples, path: "muestras", only: [] do
      member do
        post :approve, path: "aprobar"
        post :reject, path: "rechazar"
      end
    end
  end

  # Panel interno del equipo de KOVZU
  namespace :operator, path: "operador" do
    root "dashboard#show"

    resources :requirements, path: "requerimientos", only: %i[index show new create] do
      member do
        post :clarify, path: "aclaracion"
        post :answer, path: "respuesta"
        post :complete, path: "completo"
        post :reject, path: "no-viable"
        post :start_order, path: "pedido"
      end
    end

    resources :orders, path: "pedidos", only: :show do
      resources :proposals, path: "propuestas", only: %i[new create]
    end
    resources :quotes, path: "cotizaciones", only: %i[edit update] do
      post :decline, on: :member, path: "no-cotiza"
    end
    resources :tech_sheets, path: "fichas", only: %i[edit update] do
      post :ready, on: :member, path: "lista"
    end
    resources :sub_orders, path: "subpedidos", only: [] do
      resource :quote_request, path: "cotizar", only: %i[new create]
      resources :samples, path: "muestras", only: %i[new create]
    end

    resources :workshops, path: "talleres", except: :destroy do
      member do
        post :start_verification, path: "verificacion"
        post :approve_pilot, path: "piloto"
        post :pause, path: "pausa"
        post :resume, path: "reactivar"
        post :retire, path: "retiro"
      end
    end
  end

  # Living catalog of the KOVZU design system (development only)
  get "design", to: "design_system#show", as: :design if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
