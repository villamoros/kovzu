# Pregunta del operador o respuesta del cliente sobre un requerimiento.
class RequirementMessage < ApplicationRecord
  belongs_to :requirement

  validates :author_role, inclusion: { in: %w[operador cliente] }
  validates :body, presence: true
end
