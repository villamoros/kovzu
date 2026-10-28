# Inspección del lote antes del despacho (HU-12, CU-07). Al cerrarse queda inmutable y genera el acta (HU-13).
class Inspection < ApplicationRecord
  class TransitionError < ::TransitionError; end

  RESULTS = StatusCatalog.keys(:inspection_result).freeze
  REWORK_BUSINESS_DAYS = 5
  # Lo único que cambia en un acta cerrada: la decisión del cliente sobre la desviación y el envío del acta.
  MUTABLE_WHEN_CLOSED = %w[deviation_status deviation_comment deviation_decided_by deviation_decided_at report_sent_at updated_at].freeze

  enum :status, StatusCatalog.enum_for(:inspection), default: "abierta", validate: true

  belongs_to :sub_order
  belongs_to :reinspection_of, class_name: "Inspection", optional: true
  belongs_to :closed_by_user, class_name: "User", optional: true
  has_many :items, -> { order(:position) }, class_name: "InspectionItem", dependent: :destroy, inverse_of: :inspection
  has_many :approvals, as: :approvable, dependent: :restrict_with_error
  has_one_attached :report

  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :sub_order_id }
  validates :result, inclusion: { in: RESULTS }, allow_nil: true
  validates :deviation_status, inclusion: { in: %w[pendiente aceptada rechazada] }, allow_nil: true
  validate :closed_record_unchanged, on: :update

  delegate :order, :workshop, to: :sub_order

  # Abre la inspección con el checklist de la categoría, los criterios de la ficha y la muestra según el lote.
  def self.start_for!(sub_order, by:)
    raise TransitionError, "El subpedido debe tener la producción terminada." unless sub_order.inspeccion?
    if (open = sub_order.inspections.abierta.first)
      return open
    end

    sheet = sub_order.current_tech_sheet
    transaction do
      inspection = sub_order.inspections.create!(
        number: sub_order.inspections.maximum(:number).to_i + 1, reinspection_of: sub_order.inspections.cerrada.last,
        lot_size: sub_order.quantity, sample_size: SamplingPlan.sample_size(sub_order.quantity),
        tech_sheet_version: sheet&.version, criteria: sheet&.acceptance_criteria, started_by: by
      )
      checks = sub_order.category.inspection_items
      checks += [ { "key" => "criterios", "label" => "Cumple los criterios de aceptación de la ficha" } ] if sheet&.acceptance_criteria.present?
      checks.each_with_index do |check, index|
        inspection.items.create!(position: index, key: check["key"], label: check["label"], tolerance: check["tolerance"])
      end
      AuditEvent.record!(inspection, "inspeccion.iniciada", actor: by, data: { number: inspection.number })
      inspection
    end
  end

  def reinspection? = reinspection_of_id.present?

  def result_label = result && StatusCatalog.label(:inspection_result, result)
  def result_tone = result ? StatusCatalog.fetch(:inspection_result, result)[:tone] : :neutral
  def status_label = StatusCatalog.label(:inspection, status)

  def deviation_pending? = deviation_status == "pendiente"

  def nonconforming_items = items.select(&:no_conforme?)

  def suggested_rework_due_on = BusinessDays.add(Date.current, REWORK_BUSINESS_DAYS)

  # Guarda el avance sin cerrar: resultado, medición, severidad, nota y fotos de cada ítem.
  def record!(items_attrs, notes:, photos: {})
    raise TransitionError, "Esta inspección ya está cerrada." if cerrada?

    transaction do
      update!(notes:)
      items.each do |item|
        attrs = items_attrs.to_h.stringify_keys[item.id.to_s]
        item.assign_attributes(attrs.to_h.slice("result", "measurement", "severity", "note")) if attrs
        item.save!
        files = Array(photos.to_h.stringify_keys[item.id.to_s]).compact_blank
        item.photos.attach(files) if files.any?
      end
    end
  end

  # Cierra con el resultado. Desde aquí el acta no cambia (HU-12) y se envía a cliente y taller (HU-13).
  def close!(result:, user:, rework_due_on: nil)
    raise TransitionError, "Esta inspección ya está cerrada." if cerrada?

    problems = closing_problems(result, rework_due_on)
    raise TransitionError, problems.to_sentence if problems.any?

    transaction do
      update!(status: "cerrada", result:, closed_at: Time.current, closed_by: user.name, closed_by_user: user,
              rework_due_on: result == "rechazado" ? rework_due_on.to_date : nil,
              deviation_status: result == "aprobado_con_desviacion" ? "pendiente" : nil)
      AuditEvent.record!(self, "inspeccion.cerrada", actor: user.name, data: { number:, result: })
      apply_result!(user.name)
    end
    InspectionReportJob.perform_later(self)
    self
  end

  # HU-13: el cliente acepta la desviación y se habilita el saldo.
  def accept_deviation!(user:)
    raise TransitionError, "Esta acta no tiene una desviación por decidir." unless cerrada? && deviation_pending?

    transaction do
      approvals.create!(decision: "aceptada", actor_role: "cliente", actor_name: user.name, user:, version: number)
      update!(deviation_status: "aceptada", deviation_decided_by: user.name, deviation_decided_at: Time.current)
      AuditEvent.record!(self, "inspeccion.desviacion_aceptada", actor: user.name, data: { number: })
      approve_lot!
    end
  end

  # Si el cliente no acepta la desviación, se trata como rechazo (sección 3 del PRD).
  def reject_deviation!(comment, user:)
    raise TransitionError, "Esta acta no tiene una desviación por decidir." unless cerrada? && deviation_pending?
    raise TransitionError, "Cuéntanos por qué no aceptas la desviación." if comment.blank?

    transaction do
      approvals.create!(decision: "rechazada", actor_role: "cliente", actor_name: user.name, user:, version: number, comment:)
      update!(deviation_status: "rechazada", deviation_comment: comment, deviation_decided_by: user.name, deviation_decided_at: Time.current)
      AuditEvent.record!(self, "inspeccion.desviacion_rechazada", actor: user.name, data: { number: })
      reject_lot!(suggested_rework_due_on, user.name)
    end
  end

  # Cuenta como rechazo del lote: acta rechazada o desviación que el cliente no aceptó.
  def rejection? = rechazado_result? || deviation_status == "rechazada"

  def report_filename = "acta-#{order.code}-#{number}.pdf"

  private

  def rechazado_result? = cerrada? && result == "rechazado"

  def closing_problems(result, rework_due_on)
    problems = []
    pending = items.reject { |item| item.result.present? }
    problems << "Falta el resultado de: #{pending.map(&:label).to_sentence}" if pending.any?
    items.select(&:no_conforme?).each do |item|
      problems << "#{item.label}: indica la severidad" if item.severity.blank?
      problems << "#{item.label}: adjunta al menos una foto" unless item.photos.attached?
    end
    return problems if problems.any?
    return [ "Elige el resultado de la inspección" ] unless RESULTS.include?(result)

    nonconforming = nonconforming_items
    case result
    when "aprobado"
      problems << "Hay ítems no conformes: el lote no puede quedar aprobado sin desviación" if nonconforming.any?
    when "aprobado_con_desviacion"
      problems << "Una desviación necesita al menos un ítem no conforme" if nonconforming.empty?
      problems << "Una no conformidad crítica no admite desviación: el lote debe rechazarse" if nonconforming.any? { |item| item.severity == "critica" }
    when "rechazado"
      problems << "Indica el plazo de reproceso" if rework_due_on.blank?
      problems << "El plazo de reproceso debe ser una fecha futura" if rework_due_on.present? && rework_due_on.to_date <= Date.current
    end
    problems
  end

  def apply_result!(actor)
    case result
    when "aprobado" then approve_lot!
    when "aprobado_con_desviacion" then sub_order.update!(status: "aprobado_con_desviacion")
    when "rechazado" then reject_lot!(rework_due_on, actor)
    end
  end

  def approve_lot!
    sub_order.update!(status: "aprobado")
    sub_order.milestones.find_by(kind: "inspeccion")&.complete!
    ClientMailer.with(sub_order:).balance_enabled.deliver_later
  end

  # Despacho y saldo bloqueados. El taller reprocesa a su costo (RN-05); un segundo rechazo escala (RN-06).
  def reject_lot!(due_on, actor)
    if sub_order.inspections.cerrada.count(&:rejection?) >= 2
      sub_order.update!(status: "escalado")
      order.update!(status: "escalado")
      AuditEvent.record!(order, "pedido.escalado", actor:, data: { sub_order: sub_order.title, reason: "Segundo rechazo del lote" })
    else
      sub_order.update!(status: "reproceso")
      sub_order.milestones.find_by(kind: "inspeccion")
               &.reschedule!(BusinessDays.add(due_on, 1), reason: "Lote rechazado en la inspección #{number}: reproceso", responsible: "taller")
    end
  end

  def closed_record_unchanged
    return unless status_was == "cerrada"
    return if (changed - MUTABLE_WHEN_CLOSED).empty?

    errors.add(:base, "Un acta cerrada no se modifica")
  end
end
