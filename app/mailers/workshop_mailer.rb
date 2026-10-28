# Correos al taller: solicitud de cotización por enlace (HU-05) y acta de inspección (HU-13).
# No llevan datos de contacto del cliente.
class WorkshopMailer < ApplicationMailer
  def quote_request
    @quote = params[:quote]
    @sub_order = @quote.sub_order
    @url = workshop_quote_url(@quote.token)
    mail(to: @quote.workshop.email, subject: "Solicitud de cotización: #{@sub_order.title}")
  end

  def inspection_report
    @inspection = params[:inspection]
    @sub_order = @inspection.sub_order
    attachments[@inspection.report_filename] = @inspection.report.download if @inspection.report.attached?
    mail(to: @sub_order.workshop.email, subject: "Acta de inspección #{@inspection.order.code}: #{@inspection.result_label.downcase}")
  end
end
