# Panel interno del equipo de KOVZU: operador, inspector y administrador.
module Operator
  class BaseController < ApplicationController
    before_action :require_authentication!
    before_action :require_staff!

    rescue_from TransitionError, ActiveRecord::RecordInvalid do |error|
      message = error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
      redirect_back_or_to operator_root_path, alert: message
    end

    private

    def require_staff!
      return if current_user&.staff?

      redirect_to dashboard_path, alert: "Esta sección es solo para el equipo de KOVZU."
    end

    def nav_items
      [ [ "Tablero", operator_root_path ], [ "Requerimientos", operator_requirements_path ], [ "Talleres", operator_workshops_path ],
        [ "Comisiones", operator_commissions_path ] ]
    end

    def nav_home_path = operator_root_path

    def actor_name = current_user.name
  end
end
