# HU-05: el taller abre el enlace en el celular, ve la ficha y los archivos, y cotiza sin crear cuenta.
# El token del enlace es la única credencial; no se muestran datos de contacto del cliente.
class WorkshopQuotesController < ApplicationController
  rate_limit to: 20, within: 1.minute, only: %i[update decline renewal], with: -> { redirect_to workshop_quote_path(params[:token]), alert: "Demasiados intentos. Espera un minuto." }

  before_action :set_quote

  rescue_from Quote::TransitionError do |error|
    redirect_to workshop_quote_path(@quote.token), alert: error.message
  end

  def show
  end

  def update
    @quote.submit_from_link!(params.expect(quote: %i[price_cop lead_days conditions valid_until]), accept_sheet: params[:accept_sheet])
    redirect_to workshop_quote_path(@quote.token), notice: "¡Listo! Recibimos tu cotización. Te avisamos si el cliente la acepta."
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = @quote.errors.full_messages.to_sentence
    @quote.status = "solicitada"
    render :show, status: :unprocessable_entity
  end

  def decline
    raise Quote::TransitionError, "El enlace venció. Pide uno nuevo." if @quote.link_expired?

    @quote.decline!(params[:reason], by: @quote.workshop.name)
    redirect_to workshop_quote_path(@quote.token), notice: "Gracias por avisar. Le contamos al equipo de KOVZU."
  end

  def renewal
    @quote.request_renewal!
    redirect_to workshop_quote_path(@quote.token), notice: "Pedimos un enlace nuevo. Te llega por WhatsApp o correo."
  end

  private

  def set_quote
    @quote = Quote.includes(:workshop, :tech_sheet, sub_order: [ :category, { order: { requirement: { files_attachments: :blob } } } ])
                  .find_by!(token: params[:token].to_s)
  end

  def public_page? = true
end
