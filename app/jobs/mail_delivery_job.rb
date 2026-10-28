# Los correos que salen con deliver_later se reintentan si el servidor de correo falla, para que un aviso no se pierda.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  discard_on ActiveJob::DeserializationError
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
end
