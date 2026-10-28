# Recibe los reportes de la política de seguridad de contenido (modo report_only) y los deja en el log.
class CspReportsController < ActionController::Base
  FIELDS = %w[document-uri violated-directive blocked-uri source-file line-number].freeze

  skip_forgery_protection
  rate_limit to: 30, within: 1.minute, with: -> { head :too_many_requests }

  def create
    payload = JSON.parse(request.raw_post)
    report = payload.is_a?(Hash) ? payload.fetch("csp-report", payload) : nil
    Rails.logger.warn("[CSP] #{report.slice(*FIELDS).to_json}") if report.is_a?(Hash)
    head :no_content
  rescue JSON::ParserError
    head :bad_request
  end
end
