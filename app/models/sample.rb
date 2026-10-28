# Muestra patrón de un subpedido. El cliente la aprueba o la rechaza con comentarios (HU-09).
class Sample < ApplicationRecord
  class TransitionError < ::TransitionError; end

  KINDS = { "fisica" => "Física", "digital" => "Digital (fotos o video)" }.freeze
  PHOTO_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze
  RESPONSE_BUSINESS_DAYS = 3
  REJECTIONS_ALERT = 3

  enum :status, StatusCatalog.enum_for(:sample), default: "por_revisar", validate: true

  belongs_to :sub_order
  has_many_attached :photos
  has_many :approvals, as: :approvable, dependent: :restrict_with_error

  validates :kind, inclusion: { in: KINDS.keys }
  validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :sub_order_id }
  validates :photos, presence: { message: "debe tener al menos una foto" }
  validate :photos_are_images

  delegate :order, to: :sub_order

  scope :waiting_too_long, -> { por_revisar.where(created_at: ..BusinessDays.ago(RESPONSE_BUSINESS_DAYS).end_of_day) }

  def waiting_business_days = BusinessDays.between(created_at, Time.current)

  def overdue? = por_revisar? && waiting_business_days >= RESPONSE_BUSINESS_DAYS

  # Aprobada: queda como muestra patrón y el subpedido pasa a producción.
  def approve!(user:)
    raise TransitionError, "Esta muestra ya tiene una decisión." unless por_revisar?

    transaction do
      approvals.create!(decision: "aceptada", actor_role: "cliente", actor_name: user.name, user:, version: number)
      update!(status: "aprobada", decided_by: user.name, decided_at: Time.current)
      sub_order.update!(status: "en_produccion")
      sub_order.milestones.find_by(kind: "muestra")&.complete!
      AuditEvent.record!(sub_order, "muestra.aprobada", actor: user.name, data: { number: })
    end
  end

  # Rechazada: exige comentario, el taller recibe los comentarios y se fija una nueva fecha de muestra.
  def reject!(comment, user:)
    raise TransitionError, "Esta muestra ya tiene una decisión." unless por_revisar?
    raise TransitionError, "Escribe qué hay que corregir para que el taller lo sepa." if comment.blank?

    transaction do
      approvals.create!(decision: "rechazada", actor_role: "cliente", actor_name: user.name, user:, version: number, comment:)
      update!(status: "rechazada", comment:, decided_by: user.name, decided_at: Time.current)
      sub_order.increment!(:rejection_count)
      sub_order.milestones.find_by(kind: "muestra")
               &.reschedule!(BusinessDays.add(Date.current, RESPONSE_BUSINESS_DAYS), reason: "Muestra #{number} rechazada: #{comment}", responsible: "taller")
      AuditEvent.record!(sub_order, "muestra.rechazada", actor: user.name, data: { number:, rejections: sub_order.rejection_count })
    end
  end

  def status_label = StatusCatalog.label(:sample, status)

  private

  def photos_are_images
    return if photos.all? { |photo| photo.content_type.in?(PHOTO_TYPES) }

    errors.add(:photos, "solo admite fotos JPG, PNG, WEBP o HEIC")
  end
end
