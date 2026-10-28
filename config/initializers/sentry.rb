# Errores de producción en Sentry. Sin SENTRY_DSN no se envía nada (desarrollo, pruebas o un despliegue sin cuenta).
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    config.breadcrumbs_logger = %i[active_support_logger http_logger]
    # Sin datos personales: ni IP, ni cookies, ni cuerpos de las peticiones.
    config.send_default_pii = false
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0").to_f
  end
end
