class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "KOVZU <onboarding@resend.dev>")
  layout "mailer"
  self.delivery_job = MailDeliveryJob
end
