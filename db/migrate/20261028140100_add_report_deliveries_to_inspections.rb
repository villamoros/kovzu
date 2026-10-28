# El acta se envía una vez a cada destinatario: si falla el correo al taller, el reintento no le vuelve a escribir al cliente.
class AddReportDeliveriesToInspections < ActiveRecord::Migration[8.0]
  def change
    add_column :inspections, :client_report_sent_at, :datetime
    add_column :inspections, :workshop_report_sent_at, :datetime
  end
end
