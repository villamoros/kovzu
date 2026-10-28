# Propuesta al cliente: cotización elegida, fee de gestión, plazo, hitos de pago y ficha técnica (RF-08, HU-07).
class Proposal < ApplicationRecord
  class TransitionError < ::TransitionError; end

  OPEN = %w[enviada cambios_solicitados].freeze

  enum :status, StatusCatalog.enum_for(:proposal), default: "enviada", validate: true

  belongs_to :order
  belongs_to :quote
  belongs_to :tech_sheet
  has_many :approvals, as: :approvable, dependent: :restrict_with_error

  validates :workshop_price_cop, numericality: { greater_than: 0 }
  validates :management_fee_cop, numericality: { greater_than: 0 }
  validates :lead_days, numericality: { only_integer: true, greater_than: 0 }
  validates :advance_percent, numericality: { only_integer: true, in: 0..100 }
  validates :promised_on, presence: true

  delegate :workshop, :sub_order, to: :quote

  # Arma y envía la propuesta con una cotización recibida. Reemplaza la propuesta abierta anterior.
  def self.send_for!(quote, management_fee_cop:, advance_percent:, terms:, by:)
    raise TransitionError, "Solo se propone una cotización recibida." unless quote.recibida? || quote.elegida?
    raise TransitionError, "La cotización de #{quote.workshop.name} venció. Pide una nueva." if quote.offer_expired?

    sheet = quote.sub_order.current_tech_sheet
    raise TransitionError, "La ficha técnica debe estar lista, con criterios de aceptación." unless sheet&.lista? || sheet&.aceptada?

    order = quote.sub_order.order
    # Reasignación: el fee ya se causó con la primera propuesta y no se cobra otra vez (RN-07).
    fee_paid_before = order.fee_accrued_at.present?
    management_fee_cop = order.management_fee_cop if fee_paid_before
    transaction do
      order.proposals.where(status: OPEN).update_all(status: "reemplazada", updated_at: Time.current)
      quote.sub_order.quotes.elegida.where.not(id: quote.id).update_all(status: "recibida", chosen_at: nil)
      quote.update!(status: "elegida", chosen_at: Time.current)
      proposal = order.proposals.create!(quote:, tech_sheet: sheet, workshop_price_cop: quote.price_cop, management_fee_cop:,
                                         advance_percent:, terms:, lead_days: quote.lead_days, sent_by: by, sent_at: Time.current, fee_paid_before:,
                                         promised_on: BusinessDays.add(Date.current, quote.lead_days))
      order.update!(status: "propuesta_enviada")
      AuditEvent.record!(order, "propuesta.enviada", actor: by, data: { proposal_id: proposal.id, workshop: quote.workshop.name })
      ClientMailer.with(proposal:).proposal_sent.deliver_later
      proposal
    end
  end

  def total_cop = workshop_price_cop + (fee_paid_before? ? 0 : management_fee_cop)
  def advance_cop = (workshop_price_cop * advance_percent / 100).round
  def balance_cop = workshop_price_cop - advance_cop

  def quote_expired? = quote.offer_expired?

  # HU-07: el cliente acepta. Queda registro de usuario, fecha y versión, el pedido se confirma y se causa el fee (RN-07).
  def accept!(user:)
    raise TransitionError, "Esta propuesta ya no está abierta." unless enviada?
    if quote_expired?
      AuditEvent.record!(order, "propuesta.cotizacion_vencida", actor: user.name, data: { proposal_id: id })
      raise TransitionError, "La cotización del taller venció. Ya le avisamos a KOVZU para renovarla."
    end

    transaction do
      approvals.create!(decision: "aceptada", actor_role: "cliente", actor_name: user.name, user:, version: tech_sheet.version)
      accept_tech_sheet!(user)
      update!(status: "aceptada", decided_at: Time.current)
      quote.sub_order.quotes.where(status: %w[solicitada recibida]).update_all(status: "no_elegida")
      start_production_plan!
      fee = fee_paid_before? ? {} : { confirmed_at: Time.current, management_fee_cop:, fee_accrued_at: Time.current }
      order.update!(status: "confirmado", promised_on: sub_order.milestones.maximum(:committed_on) || promised_on, **fee)
      AuditEvent.record!(order, "pedido.confirmado", actor: user.name, data: { proposal_id: id, version: tech_sheet.version })
    end
    ClientMailer.with(order:, headline: "Pedido #{order.code} confirmado",
                      body: "Aceptaste la propuesta. El siguiente paso es el anticipo a #{workshop.name}.").order_update.deliver_later
  end

  # HU-07: el cliente pide cambios. Vuelve al operador y no se causa el fee.
  def request_changes!(comment, user:)
    raise TransitionError, "Esta propuesta ya no está abierta." unless enviada?
    raise TransitionError, "Cuéntanos qué quieres cambiar." if comment.blank?

    transaction do
      approvals.create!(decision: "cambios_solicitados", actor_role: "cliente", actor_name: user.name, user:,
                        version: tech_sheet.version, comment:)
      update!(status: "cambios_solicitados", change_request: comment, decided_at: Time.current)
      order.update!(status: "cotizando")
      AuditEvent.record!(order, "propuesta.cambios_solicitados", actor: user.name, data: { proposal_id: id })
    end
  end

  def status_label = StatusCatalog.label(:proposal, status)

  private

  # El taller aceptó esta versión al cotizarla; el cliente la acepta con la propuesta.
  def accept_tech_sheet!(user)
    sheet = tech_sheet.reload
    sheet.accept!(role: "taller", actor_name: workshop.name) if sheet.accepted_by_workshop_at.nil? && quote.tech_sheet_id == sheet.id
    sheet.accept!(role: "cliente", actor_name: user.name, user:)
  end

  def start_production_plan!
    sub_order.update!(workshop:, amount_cop: workshop_price_cop, status: "anticipo_pendiente")
    return if sub_order.milestones.exists?

    production_days = [ lead_days - 6, 1 ].max
    sub_order.plan_milestones!(start_on: Date.current, production_days:)
  end
end
