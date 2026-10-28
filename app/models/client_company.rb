# Empresa cliente: marca pequeña, pyme o agencia.
class ClientCompany < ApplicationRecord
  SEGMENTS = { "marca" => "Marca pequeña", "pyme" => "Pyme", "agencia" => "Agencia" }.freeze

  has_many :users, dependent: :nullify
  has_many :requirements, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error

  validates :name, presence: true
  validates :segment, inclusion: { in: SEGMENTS.keys }, allow_blank: true
  validates :nit, uniqueness: true, allow_blank: true

  def notification_emails = (users.pluck(:email) << contact_email).compact_blank.uniq

  normalizes :nit, with: ->(nit) { nit.strip.presence }
end
