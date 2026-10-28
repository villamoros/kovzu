# Lo que un taller sabe hacer en una categoría, con su rango de volumen.
class WorkshopCapability < ApplicationRecord
  belongs_to :workshop, inverse_of: :capabilities
  belongs_to :category

  validates :category_id, uniqueness: { scope: :workshop_id, message: "ya está registrada para este taller" }
  validates :min_volume, :max_volume, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :volume_range_order

  def volume_label
    min, max = [ min_volume, max_volume ].map { |value| value && ActiveSupport::NumberHelper.number_to_delimited(value, delimiter: ".") }
    return "Cualquier volumen" if min.nil? && max.nil?
    return "Desde #{min} u." if max.nil?
    return "Hasta #{max} u." if min.nil?

    "#{min}–#{max} u."
  end

  private

  def volume_range_order
    return if min_volume.nil? || max_volume.nil? || min_volume <= max_volume

    errors.add(:max_volume, "debe ser mayor o igual al mínimo")
  end
end
