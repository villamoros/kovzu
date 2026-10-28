# Punto del checklist de inspección. Un ítem no conforme exige foto y severidad (HU-12).
class InspectionItem < ApplicationRecord
  RESULTS = { "conforme" => "Conforme", "no_conforme" => "No conforme" }.freeze
  SEVERITIES = { "menor" => "Menor", "mayor" => "Mayor", "critica" => "Crítica" }.freeze

  belongs_to :inspection, inverse_of: :items
  has_many_attached :photos

  validates :key, :label, presence: true
  validates :result, inclusion: { in: RESULTS.keys }, allow_blank: true
  validates :severity, inclusion: { in: SEVERITIES.keys }, allow_blank: true
  validate :photos_are_images

  normalizes :result, :severity, with: ->(value) { value.presence }

  def no_conforme? = result == "no_conforme"
  def conforme? = result == "conforme"

  def result_label = RESULTS[result]
  def severity_label = SEVERITIES[severity]

  def readonly? = super || (persisted? && inspection&.status_was == "cerrada")

  private

  def photos_are_images
    return if photos.all? { |photo| photo.content_type.in?(Sample::PHOTO_TYPES) }

    errors.add(:photos, "solo admite fotos JPG, PNG, WEBP o HEIC")
  end
end
