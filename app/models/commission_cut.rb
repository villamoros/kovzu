# Corte mensual de comisiones (HU-20, CU-13): agrupa lo causado por taller para facturar y cobrar.
class CommissionCut < ApplicationRecord
  class TransitionError < ::TransitionError; end

  has_many :commissions, dependent: :nullify
  has_many :workshops, -> { distinct }, through: :commissions

  validates :period_start, :period_end, presence: true
  validates :period_start, uniqueness: { message: "ya tiene un corte" }

  # Toma las comisiones causadas hasta el fin del mes que aún no están en un corte.
  def self.run!(month:, by:)
    period_start = month.to_date.beginning_of_month
    raise TransitionError, "No se puede cortar un mes que no ha empezado." if period_start > Date.current
    raise TransitionError, "El corte de #{I18n.l(period_start, format: '%B %Y')} ya existe." if exists?(period_start:)

    period_end = period_start.end_of_month
    pending = Commission.uncut.where(accrued_on: ..period_end)
    raise TransitionError, "No hay comisiones causadas hasta el #{I18n.l(period_end)} para cortar." unless pending.exists?

    transaction do
      cut = create!(period_start:, period_end:, generated_by: by)
      pending.update_all(commission_cut_id: cut.id, updated_at: Time.current)
      AuditEvent.record!(cut, "comision.corte", actor: by, data: { period: period_start.to_s, total_cop: cut.commissions.sum(:amount_cop) })
      cut
    end
  end

  def name = I18n.l(period_start, format: "%B %Y").capitalize

  def to_param = period_start.strftime("%Y-%m")

  def by_workshop = commissions.active.includes(:workshop, sub_order: :order).group_by(&:workshop).sort_by { |workshop, _| workshop.name }

  # El taller recibe la factura de sus comisiones del corte.
  def invoice!(workshop, number:, invoiced_on:, due_on:, by:)
    raise TransitionError, "Escribe el número de la factura." if number.blank?

    invoiced_on = (invoiced_on.presence || Date.current).to_date
    due_on = (due_on.presence || invoiced_on).to_date
    raise TransitionError, "El vencimiento no puede ser anterior a la factura." if due_on < invoiced_on

    scope = commissions.causada.where(workshop:)
    raise TransitionError, "#{workshop.name} no tiene comisiones por facturar en este corte." unless scope.exists?

    transaction do
      scope.find_each { |commission| commission.update!(status: "facturada", invoice_number: number, invoiced_on:, due_on:) }
      AuditEvent.record!(workshop, "comision.facturada", actor: by, data: { cut: to_param, invoice: number })
    end
  end

  def mark_paid!(workshop, paid_on:, by:)
    scope = commissions.facturada.where(workshop:)
    raise TransitionError, "#{workshop.name} no tiene comisiones facturadas por cobrar en este corte." unless scope.exists?

    paid_on = (paid_on.presence || Date.current).to_date
    raise TransitionError, "La fecha de pago no puede ser futura." if paid_on > Date.current

    transaction do
      scope.update_all(status: "pagada", paid_on:, updated_at: Time.current)
      AuditEvent.record!(workshop, "comision.pagada", actor: by, data: { cut: to_param })
    end
  end
end
