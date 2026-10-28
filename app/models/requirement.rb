# Lo que pidió el cliente. El operador lo califica antes de crear la ficha técnica (HU-02).
class Requirement < ApplicationRecord
  class TransitionError < ::TransitionError; end

  CHANNELS = { "portal" => "Portal", "whatsapp" => "WhatsApp", "correo" => "Correo" }.freeze

  enum :status, StatusCatalog.enum_for(:requirement), default: "en_revision", validate: true

  belongs_to :client_company
  belongs_to :category, optional: true
  has_many :messages, -> { order(:created_at) }, class_name: "RequirementMessage", dependent: :destroy
  has_one :order, dependent: :restrict_with_error
  has_many :audit_events, as: :subject, dependent: :destroy

  validates :title, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :budget_cop, numericality: { greater_than: 0 }, allow_nil: true
  validates :channel, inclusion: { in: CHANNELS.keys }
  validates :rejection_reason, presence: true, if: :no_viable?

  before_validation { self.submitted_at ||= Time.current }

  scope :in_queue, -> { where(status: %w[en_revision esperando_cliente]).order(:submitted_at) }

  # CU-01 4a: la fecha pedida es menor que el plazo mínimo de la categoría.
  def tight_deadline?
    return false unless required_on && category

    required_on < BusinessDays.add(submitted_at || Time.current, category.min_lead_days)
  end

  def ask_clarification!(questions, by:)
    raise TransitionError, "Solo se piden aclaraciones a un requerimiento en revisión." unless en_revision?
    raise TransitionError, "Escribe las preguntas para el cliente." if questions.blank?

    transaction do
      messages.create!(author_role: "operador", author_name: by, body: questions)
      update!(status: "esperando_cliente")
      AuditEvent.record!(self, "requerimiento.aclaracion_pendiente", actor: by)
    end
  end

  # Respuesta del cliente (por el portal, o registrada por el operador si llegó por WhatsApp).
  def record_answer!(answer, by:, role: "cliente")
    raise TransitionError, "El requerimiento no está esperando respuesta." unless esperando_cliente?
    raise TransitionError, "Escribe la respuesta." if answer.blank?

    transaction do
      messages.create!(author_role: role, author_name: by, body: answer)
      update!(status: "en_revision")
      AuditEvent.record!(self, "requerimiento.respondido", actor: by)
    end
  end

  def mark_complete!(by:)
    raise TransitionError, "Solo un requerimiento en revisión se marca completo." unless en_revision?
    raise TransitionError, "Asigna una categoría antes de marcarlo completo." if category.nil?

    transaction do
      update!(status: "completo", qualified_at: Time.current)
      AuditEvent.record!(self, "requerimiento.completo", actor: by)
    end
  end

  def mark_not_viable!(reason, by:)
    raise TransitionError, "Este requerimiento ya está cerrado." if completo? || no_viable?
    raise TransitionError, "Escribe el motivo para el cliente." if reason.blank?

    transaction do
      update!(status: "no_viable", rejection_reason: reason, qualified_at: Time.current)
      AuditEvent.record!(self, "requerimiento.no_viable", actor: by, data: { reason: })
    end
  end

  def can_start_order? = completo? && order.nil?

  def waiting_days = BusinessDays.between(submitted_at, Time.current)
end
