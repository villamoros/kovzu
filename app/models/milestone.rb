# Hito de un subpedido con fecha comprometida y real (HU-08, HU-10).
class Milestone < ApplicationRecord
  class TransitionError < ::TransitionError; end

  RESPONSIBLES = { "taller" => "Taller", "cliente" => "Cliente", "kovzu" => "KOVZU" }.freeze
  ALERT_BUSINESS_DAYS = 2

  belongs_to :sub_order

  validates :kind, :title, presence: true
  validates :rescheduled_by, inclusion: { in: RESPONSIBLES.keys }, allow_nil: true

  scope :pending, -> { where(completed_on: nil) }
  scope :late, -> { pending.where(committed_on: ...Date.current) }
  scope :due_soon, -> { pending.where(committed_on: Date.current..BusinessDays.add(Date.current, ALERT_BUSINESS_DAYS)) }

  def done? = completed_on.present?

  def late? = !done? && committed_on.present? && committed_on < Date.current

  def rescheduled? = original_committed_on.present? && committed_on != original_committed_on

  # :done, :late, :current o :pending, para la línea de tiempo.
  def timeline_state(current_id = nil)
    return :done if done?
    return :late if late?

    id == current_id ? :current : :pending
  end

  def complete!(on: Date.current)
    update!(completed_on: on)
  end

  # HU-10: reprogramar exige motivo y responsable.
  def reschedule!(new_date, reason:, responsible:)
    raise TransitionError, "Escribe el motivo de la reprogramación." if reason.blank?
    raise TransitionError, "Indica quién causó el cambio." unless RESPONSIBLES.key?(responsible.to_s)

    update!(committed_on: new_date, original_committed_on: original_committed_on || committed_on,
            reschedule_reason: reason, rescheduled_by: responsible)
  end
end
