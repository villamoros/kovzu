# En desarrollo todos los correos llegan a DEV_MAIL_TO, con los destinatarios reales en el asunto.
class DevRecipientInterceptor
  def self.delivering_email(message)
    message.subject = "[para #{Array(message.to).join(', ')}] #{message.subject}"
    message.to = ENV.fetch("DEV_MAIL_TO")
    message.cc = nil
    message.bcc = nil
  end
end
