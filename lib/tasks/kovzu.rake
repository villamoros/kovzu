namespace :kovzu do
  desc "Da rol de operador a un usuario ya registrado: bin/rails kovzu:operator EMAIL=tu@correo.com"
  task operator: :environment do
    email = ENV.fetch("EMAIL") { abort "Indica el correo: EMAIL=tu@correo.com" }
    user = User.find_by(email:) || abort("No hay un usuario con #{email}. Entra una vez con Clerk y vuelve a intentarlo.")
    user.update!(role: ENV.fetch("ROLE", "operador"))
    puts "#{user.name} ahora es #{user.role}."
  end
end
