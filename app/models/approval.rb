# Registro inmutable de una decisión: quién aprobó qué, cuándo y sobre qué versión.
class Approval < ApplicationRecord
  belongs_to :approvable, polymorphic: true
  belongs_to :user, optional: true

  validates :decision, inclusion: { in: %w[aceptada rechazada cambios_solicitados] }
  validates :actor_role, inclusion: { in: %w[cliente taller operador inspector] }
  validates :actor_name, presence: true

  def readonly? = persisted?
end
