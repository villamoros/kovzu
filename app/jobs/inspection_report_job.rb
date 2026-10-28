# HU-13: genera el acta en PDF y la envía a cliente y taller apenas se cierra la inspección.
class InspectionReportJob < ApplicationJob
  queue_as :default

  def perform(inspection)
    unless inspection.report.attached?
      inspection.report.attach(io: StringIO.new(InspectionReportPdf.new(inspection).render),
                               filename: inspection.report_filename, content_type: "application/pdf")
    end
    ClientMailer.with(inspection:).inspection_report.deliver_now
    WorkshopMailer.with(inspection:).inspection_report.deliver_now if inspection.workshop&.email.present?
    inspection.update!(report_sent_at: Time.current)
  end
end
