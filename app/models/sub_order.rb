# Parte de un pedido que fabrica un solo taller.
class SubOrder < ApplicationRecord
  class TransitionError < ::TransitionError; end

  MAX_QUOTES = 3
  QUOTE_LINK_TTL = 5.days

  enum :status, StatusCatalog.enum_for(:sub_order), default: "preparacion", validate: true

  belongs_to :order, inverse_of: :sub_orders
  belongs_to :category
  belongs_to :workshop, optional: true
  has_many :tech_sheets, -> { order(version: :desc) }, dependent: :destroy, inverse_of: :sub_order
  has_many :quotes, -> { order(:created_at) }, dependent: :destroy
  has_many :milestones, -> { order(:position) }, dependent: :destroy
  has_many :samples, -> { order(:number) }, dependent: :destroy
  has_many :inspections, -> { order(:number) }, dependent: :restrict_with_error
  has_many :payments, -> { order(:created_at) }, dependent: :restrict_with_error
  has_many :commissions, dependent: :restrict_with_error

  validates :title, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  def current_tech_sheet = tech_sheets.first

  def open_quotes = quotes.where(status: %w[solicitada recibida])

  # Pide cotización a 1–3 talleres verificados con la ficha lista (HU-04).
  def request_quotes!(workshop_ids, by:)
    sheet = current_tech_sheet
    raise TransitionError, "La ficha técnica debe estar lista antes de pedir cotizaciones." unless sheet&.lista? || sheet&.aceptada?

    workshops = Workshop.where(id: Array(workshop_ids).compact_blank).to_a
    raise TransitionError, "Elige entre 1 y #{MAX_QUOTES} talleres." unless workshops.size.between?(1, MAX_QUOTES)
    raise TransitionError, "Ya hay #{open_quotes.count} cotizaciones abiertas; el máximo es #{MAX_QUOTES}." if open_quotes.count + workshops.size > MAX_QUOTES

    eligible = Workshop.candidates_for(self).where(id: workshops.map(&:id)).pluck(:id)
    rejected = workshops.reject { |workshop| eligible.include?(workshop.id) }
    raise TransitionError, "No cumplen las condiciones para cotizar: #{rejected.map(&:name).to_sentence}." if rejected.any?

    transaction do
      created = workshops.map do |workshop|
        quotes.create!(workshop:, tech_sheet: sheet, link_expires_at: QUOTE_LINK_TTL.from_now)
      end
      update!(status: "cotizando")
      order.update!(status: "cotizando") if order.en_preparacion?
      AuditEvent.record!(self, "cotizacion.solicitada", actor: by, data: { workshops: workshops.map(&:name) })
      created
    end.each { |quote| WorkshopMailer.with(quote:).quote_request.deliver_later if quote.workshop.email.present? }
  end

  # HU-19: la muestra se registra después del anticipo.
  SAMPLE_STATUSES = %w[muestra_pendiente].freeze

  def current_sample = samples.last

  def can_register_sample? = status.in?(SAMPLE_STATUSES) && !current_sample&.por_revisar?

  # El operador registra la muestra con fotos y el cliente la revisa (HU-09).
  def register_sample!(kind:, notes:, photos:, by:)
    raise TransitionError, "Este subpedido no está esperando muestra." unless status.in?(SAMPLE_STATUSES)
    raise TransitionError, "La muestra anterior sigue esperando respuesta del cliente." if current_sample&.por_revisar?

    sample = transaction do
      created = samples.create!(number: samples.maximum(:number).to_i + 1, kind:, notes:, photos:, registered_by: by)
      update!(status: "muestra_pendiente")
      order.update!(status: "en_curso") if order.confirmado?
      AuditEvent.record!(self, "muestra.registrada", actor: by, data: { number: created.number })
      created
    end
    ClientMailer.with(order:, headline: "Tu muestra está lista para revisar",
                      body: "Registramos la muestra #{sample.number} de #{title}. Revísala y apruébala o pide ajustes.").order_update.deliver_later
    sample
  end

  # Producción terminada (o reproceso terminado): el lote queda listo para inspección (CU-07).
  def finish_production!(by:)
    raise TransitionError, "Solo se marca terminado un subpedido en producción o en reproceso." unless en_produccion? || reproceso?

    rework = reproceso?
    transaction do
      update!(status: "inspeccion")
      milestones.find_by(kind: "produccion")&.then { |milestone| milestone.complete! unless milestone.done? }
      AuditEvent.record!(self, rework ? "produccion.reproceso_terminado" : "produccion.terminada", actor: by)
    end
    ClientMailer.with(order:, headline: "#{title}: listo para inspección",
                      body: "El taller terminó #{rework ? 'el reproceso' : 'la producción'}. Vamos a inspeccionar el lote antes del despacho.").order_update.deliver_later
  end

  def current_inspection = inspections.last

  def accepted_proposal
    order.proposals.select(&:aceptada?).find { |proposal| proposal.quote.sub_order_id == id }
  end

  # Valor pactado de cada pago: el de la propuesta aceptada o, sin propuesta, la mitad del valor del taller.
  def expected_payment_cop(kind)
    proposal = accepted_proposal
    advance = proposal ? proposal.advance_cop.to_i : (amount_cop.to_i / 2.0).round
    total = proposal ? proposal.workshop_price_cop.to_i : amount_cop.to_i
    kind.to_s == "anticipo" ? advance : total - advance
  end

  def payment(kind) = payments.find { |payment| payment.vigente? && payment.kind == kind.to_s }

  def can_register_advance? = anticipo_pendiente? && payment(:anticipo).nil?

  # RF-29: el saldo se habilita solo con el acta aprobada (o la desviación aceptada).
  def balance_enabled? = aprobado? && payment(:saldo).nil?

  def balance_paid? = payment(:saldo).present?

  # HU-19: registra el pago con su soporte. Si el valor no coincide con lo pactado, pide confirmar.
  def register_payment!(kind:, amount_cop:, paid_on:, support:, by:, notes: nil, confirm_mismatch: false)
    kind = kind.to_s
    raise TransitionError, "Tipo de pago no válido." unless Payment::KINDS.key?(kind)
    raise TransitionError, "Ya hay un #{Payment::KINDS[kind].downcase} registrado. Anúlalo para registrar otro." if payment(kind)
    if kind == "anticipo"
      raise TransitionError, "El anticipo se registra con el pedido confirmado y antes de la muestra." unless anticipo_pendiente?
    else
      raise TransitionError, "El saldo se habilita cuando el acta de inspección queda aprobada." unless aprobado?
    end

    record = Payment.new(sub_order: self, kind:, amount_cop:, paid_on:, support:, notes:, registered_by: by, expected_cop: expected_payment_cop(kind))
    record.validate!
    if record.mismatch? && !ActiveModel::Type::Boolean.new.cast(confirm_mismatch)
      expected = ActiveSupport::NumberHelper.number_to_currency(record.expected_cop, locale: :es)
      raise Payment::AmountMismatch, "El valor no coincide con lo pactado (#{expected}). Revísalo y confirma si es correcto."
    end

    transaction do
      record.save!
      if kind == "anticipo"
        update!(status: "muestra_pendiente")
        milestones.find_by(kind: "anticipo")&.complete!(on: record.paid_on)
      else
        Commission.accrue!(record)
      end
      AuditEvent.record!(self, "pago.registrado", actor: by,
                         data: { kind:, amount_cop: record.amount_cop, difference_cop: record.mismatch? ? record.difference_cop : nil }.compact)
    end
    payments.reset
    record
  end

  # Al anular un pago, el subpedido vuelve al paso anterior si nada avanzó desde entonces.
  def reopen_after_void!(payment)
    return unless payment.kind == "anticipo" && muestra_pendiente? && samples.none?

    update!(status: "anticipo_pendiente")
    milestones.find_by(kind: "anticipo")&.update!(completed_on: nil)
  end

  # Con el saldo pagado se despacha y se entrega. El pedido se cierra cuando todos sus subpedidos se entregan.
  def deliver!(by:)
    raise TransitionError, "El despacho se habilita con el acta aprobada y el saldo pagado." unless aprobado? && balance_paid?

    transaction do
      update!(status: "entregado")
      milestones.find_by(kind: "despacho")&.complete!
      AuditEvent.record!(self, "subpedido.entregado", actor: by)
      order.update!(status: "entregado", delivered_at: Time.current) if order.sub_orders.reload.all?(&:entregado?)
    end
    ClientMailer.with(order:, headline: "#{title} entregado",
                      body: "Registramos la entrega. Si encuentras algo fuera de la ficha, tienes 10 días calendario para reclamar.").order_update.deliver_later
  end

  # Hitos estándar desde una fecha de inicio, en días hábiles.
  def plan_milestones!(start_on:, sample_days: 3, production_days: 8)
    steps = [
      [ "anticipo", "Anticipo al taller", 1 ],
      [ "muestra", "Muestra patrón", sample_days ],
      [ "produccion", "Producción", production_days ],
      [ "inspeccion", "Inspección", 1 ],
      [ "despacho", "Despacho y entrega", 1 ]
    ]
    date = start_on.to_date
    steps.each_with_index.map do |(kind, title, days), index|
      date = BusinessDays.add(date, days)
      milestones.create!(kind:, title:, position: index, committed_on: date, original_committed_on: date)
    end
  end

  def status_label = StatusCatalog.label(:sub_order, status)
end
