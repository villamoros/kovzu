# Be sure to restart your server when you modify this file.

# Política de seguridad de contenido: una segunda barrera si algún día aparece un XSS.
# Va en modo report_only: el navegador no bloquea nada, solo reporta a /csp-reports (queda en el log).
# Cuando el log pase unas semanas sin reportes legítimos, se quita report_only para que bloquee.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  # La llave publicable de Clerk trae el host de su Frontend API, que sirve clerk-js y recibe sus llamadas.
  clerk_host = Base64.decode64(ENV["CLERK_PUBLISHABLE_KEY"].to_s.split("_", 3).last.to_s).delete_suffix("$").presence
  clerk = [ ("https://#{clerk_host}" if clerk_host), "https://*.clerk.accounts.dev" ].compact
  turnstile = "https://challenges.cloudflare.com" # verificación anti-bots de Clerk
  r2 = "https://*.r2.cloudflarestorage.com"        # URLs firmadas de los archivos (FilesController)

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.frame_ancestors :none
    policy.script_src :self, *clerk, turnstile
    # Clerk inyecta estilos en línea y varias vistas usan atributos style.
    policy.style_src :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src :self, :data, "https://fonts.gstatic.com"
    policy.img_src :self, :data, :blob, r2, "https://img.clerk.com"
    policy.connect_src :self, *clerk, "https://clerk-telemetry.com"
    policy.frame_src turnstile
    policy.worker_src :self, :blob
    policy.report_uri "/csp-reports"
  end

  # Nonces para el importmap y los scripts en línea (el tema claro u oscuro en kz/_head).
  # Uno por sesión y no por petición, para que Turbo pueda reutilizarlo entre visitas.
  config.content_security_policy_nonce_generator = ->(request) { request.session[:csp_nonce] ||= SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]

  config.content_security_policy_report_only = true
end
