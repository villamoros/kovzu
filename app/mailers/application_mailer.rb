class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "KOVZU <onboarding@resend.dev>")
  layout "mailer"
end
