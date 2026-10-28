# Panel interno del equipo de KOVZU: operador, inspector y administrador.
# Operador y administrador hacen todo. El inspector ve la operación e inspecciona: las acciones que cada
# controlador le abre con `inspector_can`. Pagos, comisiones, propuestas, cotizaciones y talleres no.
module Operator
  class BaseController < ApplicationController
    class_attribute :inspector_actions, instance_writer: false, default: [].freeze

    def self.inspector_can(*actions)
      self.inspector_actions = actions.map(&:to_s).freeze
    end

    before_action :require_authentication!
    before_action :require_staff!
    before_action :require_role_permission!

    helper_method :can_operate?

    rescue_from TransitionError, ActiveRecord::RecordInvalid do |error|
      message = error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
      redirect_back_or_to operator_root_path, alert: message
    end

    private

    def require_staff!
      return if current_user&.staff?

      redirect_to dashboard_path, alert: "Esta sección es solo para el equipo de KOVZU."
    end

    def require_role_permission!
      return if can_operate? || action_name.in?(inspector_actions)

      redirect_to operator_root_path, alert: "Tu rol de inspector no permite esta acción. Pídesela a un operador."
    end

    # Operador o administrador: pagos, comisiones, propuestas, cotizaciones y talleres.
    def can_operate? = current_user.operador? || current_user.admin?

    def nav_items
      items = [ [ "Tablero", operator_root_path ], [ "Requerimientos", operator_requirements_path ], [ "Talleres", operator_workshops_path ] ]
      items << [ "Comisiones", operator_commissions_path ] if can_operate?
      items
    end

    def nav_home_path = operator_root_path

    def actor_name = current_user.name
  end
end
