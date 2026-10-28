# HU-13: genera el acta en PDF y la envía a cliente y taller apenas se cierra la inspección.
# Cada envío queda marcado antes del siguiente: si falla el correo al taller, el reintento no le vuelve a escribir al cliente.
class InspectionReportJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(inspection)
    return if inspection.report_sent_at

    unless inspection.report.attached?
      inspection.report.attach(io: StringIO.new(InspectionReportPdf.new(inspection).render),
                               filename: inspection.report_filename, content_type: "application/pdf")
    end
    deliver_once(inspection, :client_report_sent_at) { ClientMailer.with(inspection:).inspection_report }
    if inspection.workshop&.email.present?
      deliver_once(inspection, :workshop_report_sent_at) { WorkshopMailer.with(inspection:).inspection_report }
    end
    inspection.update!(report_sent_at: Time.current)
  end

  private

  def deliver_once(inspection, sent_at)
    return if inspection[sent_at]

    yield.deliver_now
    inspection.update!(sent_at => Time.current)
  end
end
