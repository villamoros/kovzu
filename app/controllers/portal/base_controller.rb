# Portal del cliente: cada usuario ve solo lo de su empresa.
module Portal
  class BaseController < ApplicationController
    before_action :require_authentication!
    before_action :require_client_company!

    rescue_from TransitionError, ActiveRecord::RecordInvalid do |error|
      message = error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
      redirect_back_or_to dashboard_path, alert: message
    end

    helper_method :current_company

    private

    def current_company = current_user&.client_company

    # El equipo de KOVZU va a su panel; un cliente nuevo registra primero su empresa.
    def require_client_company!
      return redirect_to operator_root_path if current_user.staff?

      redirect_to new_company_path unless current_company
    end

    def nav_items
      [ [ "Inicio", dashboard_path ], [ "Requerimientos", requirements_path ], [ "Pedidos", orders_path ] ]
    end
  end
end
