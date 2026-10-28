require "test_helper"

# CSP en modo reporte: el navegador no bloquea, pero reporta a /csp-reports.
class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "las páginas llevan la política de seguridad en modo reporte, con nonce para los scripts" do
    get root_path
    assert_response :success

    policy = response.headers["Content-Security-Policy-Report-Only"]
    assert policy, "falta la cabecera de CSP"
    assert_nil response.headers["Content-Security-Policy"], "todavía no bloquea"
    assert_match "default-src 'self'", policy
    assert_match "object-src 'none'", policy
    assert_match "frame-ancestors 'none'", policy
    assert_match %r{script-src 'self' [^;]*https://challenges\.cloudflare\.com 'nonce-}, policy
    assert_match "report-uri /csp-reports", policy

    nonce = policy[/'nonce-([^']+)'/, 1]
    assert_select "script[nonce=?]", nonce
  end

  test "el reporte de CSP queda en el log" do
    report = { "csp-report" => { "document-uri" => "https://kovzu.co/", "violated-directive" => "script-src", "blocked-uri" => "https://malo.example" } }
    post "/csp-reports", params: report.to_json, headers: { "Content-Type" => "application/csp-report" }
    assert_response :no_content

    post "/csp-reports", params: "no es json", headers: { "Content-Type" => "application/csp-report" }
    assert_response :bad_request
  end
end
