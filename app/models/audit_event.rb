# Bitácora de auditoría. Cada evento queda ligado a su pedido cuando lo tiene.
class AuditEvent < ApplicationRecord
  belongs_to :subject, polymorphic: true
  belongs_to :order, optional: true

  validates :action, presence: true

  def self.record!(subject, action, actor:, data: {})
    create!(subject:, order: order_for(subject), action:, actor_name: actor, data:)
  end

  def self.order_for(subject)
    case subject
    when Order then subject
    when SubOrder then subject.order
    when TechSheet, Quote, Milestone then subject.sub_order.order
    when Requirement then subject.order
    end
  end

  def readonly? = persisted?
end
