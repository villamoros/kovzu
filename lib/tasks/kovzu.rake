namespace :kovzu do
  desc "Da rol de operador a un usuario ya registrado: bin/rails kovzu:operator EMAIL=tu@correo.com"
  task operator: :environment do
    email = ENV.fetch("EMAIL") { abort "Indica el correo: EMAIL=tu@correo.com" }
    user = User.find_by(email:) || abort("No hay un usuario con #{email}. Entra una vez con Clerk y vuelve a intentarlo.")
    user.update!(role: ENV.fetch("ROLE", "operador"))
    puts "#{user.name} ahora es #{user.role}."
  end

  desc "Asocia un usuario a una empresa cliente: bin/rails kovzu:client EMAIL=tu@correo.com COMPANY=\"Aroma de Café SAS\""
  task client: :environment do
    email = ENV.fetch("EMAIL") { abort "Indica el correo: EMAIL=tu@correo.com" }
    user = User.find_by(email:) || abort("No hay un usuario con #{email}. Entra una vez con Clerk y vuelve a intentarlo.")
    company = ClientCompany.find_by(name: ENV.fetch("COMPANY") { abort "Indica la empresa: COMPANY=\"Aroma de Café SAS\"" }) || abort("No existe esa empresa.")
    user.update!(role: "cliente", client_company: company, data_consent_at: user.data_consent_at || Time.current)
    puts "#{user.name} ahora ve los pedidos de #{company.name}."
  end
end
