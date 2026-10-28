class ApplicationController < ActionController::Base
  include Clerk::Authenticatable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :signed_in?

  private

  def signed_in?
    clerk&.user? || false
  end

  # Local user record mirrored from Clerk, so app data can reference users.
  def current_user
    return unless signed_in?

    @current_user ||= User.find_by(clerk_id: clerk.user_id) || User.sync_from_clerk(clerk.user)
  end

  def require_authentication!
    redirect_to sign_in_path(redirect_url: request.original_url) unless signed_in?
  end
end
