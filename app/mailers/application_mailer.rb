class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "KOVZU <notificaciones@example.com>")
  layout "mailer"
end
