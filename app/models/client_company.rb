# Empresa cliente: marca pequeña, pyme o agencia.
class ClientCompany < ApplicationRecord
  SEGMENTS = { "marca" => "Marca pequeña", "pyme" => "Pyme", "agencia" => "Agencia" }.freeze

  has_many :users, dependent: :nullify
  has_many :requirements, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error

  validates :name, presence: true
  validates :segment, inclusion: { in: SEGMENTS.keys }, allow_blank: true
  validates :nit, uniqueness: true, allow_blank: true

  normalizes :nit, with: ->(nit) { nit.strip.presence }
end
