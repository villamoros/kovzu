class ApplicationController < ActionController::Base
  include Clerk::Authenticatable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :signed_in?, :nav_items, :nav_home_path, :public_page?

  private

  def signed_in?
    clerk&.user? || false
  end

  # Local user record mirrored from Clerk, so app data can reference users.
  def current_user
    return unless signed_in?

    @current_user ||= User.find_by(clerk_id: clerk.user_id) || User.sync_from_clerk(clerk.user)
  end

  # Enlaces de la barra superior. El panel del operador los reemplaza.
  def nav_items
    return [] unless signed_in?

    items = [ [ "Inicio", dashboard_path ] ]
    items << [ "Operación", operator_root_path ] if current_user&.staff?
    items
  end

  def nav_home_path = signed_in? ? dashboard_path : root_path

  # Páginas abiertas por enlace (el taller cotizando): sin botones de cuenta en la barra.
  def public_page? = false

  def require_authentication!
    redirect_to sign_in_path(redirect_url: request.original_url) unless signed_in?
  end
end
