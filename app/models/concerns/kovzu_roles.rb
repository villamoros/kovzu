# Roles de KOVZU sobre el usuario de Clerk. Se incluye en User.
module KovzuRoles
  extend ActiveSupport::Concern

  ROLES = %w[cliente operador inspector admin].freeze

  included do
    enum :role, ROLES.index_with(&:itself), default: "cliente", validate: true
    belongs_to :client_company, optional: true
  end

  # Operador, inspector o administrador: ve el panel interno.
  def staff? = operador? || inspector? || admin?
end
