# Sirve los archivos adjuntos (diseños, fotos, actas y soportes) después de revisar quién los pide.
# Redirige a una URL firmada que vence en minutos, en el disco local o en Cloudflare R2.
class FilesController < ApplicationController
  include ActiveStorage::SetCurrent

  URL_EXPIRES_IN = 5.minutes

  def show
    attachment = ActiveStorage::Attachment.includes(:blob).find(params[:id])
    raise ActiveRecord::RecordNotFound unless FileAccess.new(attachment).allowed?(user: current_user, quote: workshop_quote)

    disposition = params[:disposition] == "attachment" ? :attachment : :inline
    response.headers["Cache-Control"] = "private, no-store"
    redirect_to attachment.url(disposition:, expires_in: URL_EXPIRES_IN), allow_other_host: true
  end

  private

  def workshop_quote
    Quote.find_by(token: params[:token].to_s) if params[:token].present?
  end

  # Los archivos de la ficha se abren desde el enlace del taller, también en celulares viejos.
  def public_page? = params[:token].present?
end
