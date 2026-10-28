# Correos al cliente en cada paso de su requerimiento y su pedido (RF-13).
class ClientMailer < ApplicationMailer
  # HU-01: confirmación del envío.
  def requirement_received
    @requirement = params[:requirement]
    @url = requirement_url(@requirement)
    notify(@requirement.client_company, "Recibimos tu requerimiento: #{@requirement.title}")
  end

  # HU-02: el operador necesita más información.
  def clarification_requested
    @requirement = params[:requirement]
    @questions = params[:questions]
    @url = requirement_url(@requirement)
    notify(@requirement.client_company, "Tenemos preguntas sobre #{@requirement.title}")
  end

  def not_viable
    @requirement = params[:requirement]
    @url = requirement_url(@requirement)
    notify(@requirement.client_company, "Sobre tu requerimiento #{@requirement.title}")
  end

  # HU-07: propuesta lista para revisar.
  def proposal_sent
    @proposal = params[:proposal]
    @order = @proposal.order
    @url = order_proposal_url(@order)
    notify(@order.client_company, "Tu propuesta para #{@order.title} está lista")
  end

  # HU-08: cualquier cambio de estado del pedido.
  def order_update
    @order = params[:order]
    @headline = params[:headline]
    @body = params[:body]
    @url = order_url(@order)
    notify(@order.client_company, @headline)
  end

  private

  def notify(company, subject)
    recipients = company.notification_emails
    mail(to: recipients, subject:) if recipients.any?
  end
end
