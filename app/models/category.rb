# Categoría de capacidad manufacturera, con sus plantillas de ficha técnica e inspección.
class Category < ApplicationRecord
  # Campos comunes del requerimiento que precargan la ficha técnica (HU-03).
  REQUIREMENT_FIELDS = {
    "producto" => :title,
    "cantidad" => :quantity,
    "dimensiones" => :dimensions,
    "material" => :material,
    "acabado" => :finish
  }.freeze

  has_many :workshop_capabilities, dependent: :restrict_with_error
  has_many :workshops, through: :workshop_capabilities
  has_many :requirements, dependent: :restrict_with_error
  has_many :sub_orders, dependent: :restrict_with_error

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true
  validates :min_lead_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true).order(:position, :name) }

  def tech_sheet_fields = Array(tech_sheet_template)
  def inspection_items = Array(inspection_template)

  def required_tech_sheet_keys
    tech_sheet_fields.select { |field| field["required"] }.map { |field| field["key"] }
  end
end
