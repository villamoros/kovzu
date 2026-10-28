# KOVZU

Rails 8 · Hotwire (Turbo + Stimulus, importmap) · Tailwind CSS 4 · PostgreSQL · Clerk.

El sistema de diseño está documentado en [docs/design-system.md](docs/design-system.md) y su catálogo vive en `/design` (solo desarrollo).

## Puesta en marcha local

Requisitos: Ruby 3.4, PostgreSQL 17 corriendo en local y una app creada en [dashboard.clerk.com](https://dashboard.clerk.com).

1. Copia `.env.example` a `.env` y rellena:
   - `PGPASSWORD`: la contraseña de tu usuario `postgres` local.
   - `CLERK_PUBLISHABLE_KEY` y `CLERK_SECRET_KEY`: en Clerk → API keys.
2. Instala y prepara la base de datos:

   ```bash
   bundle install
   bin/rails db:prepare
   ```

3. Arranca la app (servidor + Tailwind en modo watch):

   ```bash
   bin/dev
   ```

   En Windows, si `bin/dev` no arranca, usa dos terminales: `ruby bin/rails server` y `ruby bin/rails tailwindcss:watch`.

Abre http://localhost:3000.

## Autenticación

- Clerk monta sus componentes (`SignIn`, `SignUp`, `UserButton`) desde `app/javascript/controllers/clerk_controller.js`, con los colores del sistema de diseño.
- En el servidor, el middleware de `clerk-sdk-ruby` valida la sesión. `ApplicationController` expone `signed_in?`, `current_user` y `require_authentication!`.
- La primera vez que alguien entra se crea su `User` local (columna `clerk_id`), para que los datos de la app puedan apuntar a usuarios.

## Producción

La app lee `DATABASE_URL` (Neon o Supabase). Solid Cache, Queue y Cable comparten esa misma base, así que basta una base gratuita. Variables necesarias: `DATABASE_URL`, `RAILS_MASTER_KEY`, `CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`.
