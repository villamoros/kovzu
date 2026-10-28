# Ficha técnica versionada: qué significa "bien hecho" para un subpedido (HU-03).
# Una ficha aceptada no se edita: se crea una versión nueva que exige nueva aceptación.
class TechSheet < ApplicationRecord
  class TransitionError < ::TransitionError; end

  EDITABLE_ATTRIBUTES = %w[fields acceptance_criteria].freeze

  enum :status, StatusCatalog.enum_for(:tech_sheet), default: "borrador", validate: true

  belongs_to :sub_order, inverse_of: :tech_sheets
  has_many :quotes, dependent: :restrict_with_error
  has_many :approvals, as: :approvable, dependent: :restrict_with_error

  validates :version, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :sub_order_id }
  validate :locked_content_unchanged, on: :update

  delegate :category, to: :sub_order

  # Precarga los campos de la plantilla con lo que pidió el cliente.
  def self.build_from(requirement, sub_order)
    values = sub_order.category.tech_sheet_fields.to_h do |field|
      key = field["key"]
      source = Category::REQUIREMENT_FIELDS[key]
      [ key, (source ? requirement.public_send(source) : requirement.details[key]).to_s.presence ]
    end
    sub_order.tech_sheets.build(fields: values.compact)
  end

  def template_fields = category.tech_sheet_fields

  def value(key) = fields[key.to_s]

  def missing_required_fields
    category.tech_sheet_fields.select { |field| field["required"] && value(field["key"]).blank? }.map { |field| field["label"] }
  end

  def editable? = borrador? || lista?

  # Borrador → Lista: con campos obligatorios y criterios de aceptación (HU-03).
  def mark_ready!(by:)
    raise TransitionError, "Solo un borrador se marca como lista." unless borrador?
    raise TransitionError, "Faltan criterios de aceptación." if acceptance_criteria.blank?
    raise TransitionError, "Faltan campos obligatorios: #{missing_required_fields.to_sentence}." if missing_required_fields.any?

    update!(status: "lista")
    AuditEvent.record!(self, "ficha.lista", actor: by, data: { version: })
  end

  # Cambia el contenido. Si la ficha ya fue aceptada, crea la versión siguiente y deja esta como reemplazada.
  def revise!(attrs, by:)
    attrs = attrs.to_h.stringify_keys.slice(*EDITABLE_ATTRIBUTES)
    if editable?
      assign_attributes(attrs)
      self.status = "borrador" if lista? && changed?
      save!
      return self
    end
    raise TransitionError, "Esta versión ya fue reemplazada." if reemplazada?

    transaction do
      content = { "fields" => fields, "acceptance_criteria" => acceptance_criteria }.merge(attrs)
      next_sheet = sub_order.tech_sheets.create!(content.merge("version" => version + 1))
      update_column(:status, "reemplazada")
      AuditEvent.record!(next_sheet, "ficha.nueva_version", actor: by, data: { version: next_sheet.version })
      next_sheet
    end
  end

  # Aceptación de cliente o taller (HU-07). Con las dos, la ficha queda aceptada.
  def accept!(role:, actor_name:, user: nil)
    raise TransitionError, "La ficha debe estar lista para aceptarla." unless lista? || aceptada?
    raise TransitionError, "Rol no válido." unless %w[cliente taller].include?(role)

    transaction do
      approvals.create!(decision: "aceptada", actor_role: role, actor_name:, user:, version:)
      column = role == "cliente" ? :accepted_by_client_at : :accepted_by_workshop_at
      self[column] = Time.current
      self.status = "aceptada" if accepted_by_client_at && accepted_by_workshop_at
      save!
    end
  end

  def status_label = StatusCatalog.label(:tech_sheet, status)

  private

  def locked_content_unchanged
    return if status_was.in?(%w[borrador lista])
    return unless (changed & EDITABLE_ATTRIBUTES).any?

    errors.add(:base, "Una ficha aceptada no se edita: crea una versión nueva")
  end
end
