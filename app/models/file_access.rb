# Quién puede abrir un archivo adjunto. Ningún archivo tiene un enlace permanente: FilesController
# revisa este permiso y redirige a una URL firmada que vence en minutos.
class FileAccess
  # Lo que ve el cliente de su propia empresa. Los soportes de pago y las cotizaciones del taller son internos.
  CLIENT_RECORDS = %w[Requirement Sample Inspection InspectionItem].freeze

  def initialize(attachment)
    @attachment = attachment
  end

  # quote: la cotización del enlace del taller, cuando el archivo se pide desde esa página.
  def allowed?(user:, quote: nil)
    return true if user&.staff?
    return workshop_can_open?(quote) if quote

    client_can_open?(user)
  end

  private

  attr_reader :attachment

  def record = attachment.record

  # El taller solo ve los archivos del requerimiento, mientras su enlace sirve para cotizar.
  def workshop_can_open?(quote)
    record.is_a?(Requirement) && quote.sub_order.order.requirement_id == record.id && quote.link_usable?
  end

  def client_can_open?(user)
    company = user&.client_company
    return false unless company && attachment.record_type.in?(CLIENT_RECORDS)
    return false if inspection && !inspection.cerrada?

    owner_company_id == company.id
  end

  def inspection
    case record
    when Inspection then record
    when InspectionItem then record.inspection
    end
  end

  def owner_company_id
    case record
    when Requirement then record.client_company_id
    when InspectionItem then record.inspection.sub_order.order.client_company_id
    else record.sub_order.order.client_company_id
    end
  end
end
