# Categorías y plantillas: necesarias en todos los entornos. Idempotente.
load Rails.root.join("db/seeds/categories.rb")

# Datos de ejemplo: solo en desarrollo.
load Rails.root.join("db/seeds/demo.rb") if Rails.env.development?
