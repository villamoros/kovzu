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

## Datos de ejemplo

`db/seeds/demo.rb` carga en desarrollo clientes, talleres y pedidos en todos los estados: cotizando por enlace, propuesta enviada, muestra por revisar, inspección abierta, acta con desviación, saldo por registrar, entregados, un taller en mora y tres lotes con segundo rechazo (por decidir, descuento esperando al cliente y reasignado con el anticipo por devolver). Solo se carga si no hay pedidos, así que para empezar de cero:

```bash
bin/rails db:seed:replant   # borra los datos y vuelve a sembrar
```

Entra una vez con Clerk y dale un rol a tu usuario. Puedes alternar entre los dos lados con la misma cuenta:

```bash
bin/rails kovzu:operator EMAIL=tu@correo.com                              # panel /operador
bin/rails kovzu:client EMAIL=tu@correo.com COMPANY="Aroma de Café SAS"   # portal del cliente
```

Al sembrar, la consola imprime el enlace `/cotizar/...` que vería el taller Cartón Valle.

## Correos

Salen por Resend (SMTP) con `RESEND_API_KEY`. En desarrollo solo se envían si además defines `DEV_MAIL_TO`, y todos llegan a ese buzón. Sin un dominio verificado en Resend, solo se entregan al correo de tu cuenta de Resend.

## Autenticación

- Clerk monta sus componentes (`SignIn`, `SignUp`, `UserButton`) desde `app/javascript/controllers/clerk_controller.js`, con los colores del sistema de diseño.
- En el servidor, el middleware de `clerk-sdk-ruby` valida la sesión. `ApplicationController` expone `signed_in?`, `current_user` y `require_authentication!`.
- La primera vez que alguien entra se crea su `User` local (columna `clerk_id`), para que los datos de la app puedan apuntar a usuarios.

## Producción

La app lee `DATABASE_URL` (Neon o Supabase). Solid Cache, Queue y Cable comparten esa misma base, así que basta una base gratuita. Variables necesarias: `DATABASE_URL`, `RAILS_MASTER_KEY`, `CLERK_PUBLISHABLE_KEY`, `CLERK_SECRET_KEY`, `RESEND_API_KEY`, `MAIL_FROM` (con un dominio verificado en Resend) y `APP_HOST` (el dominio público, para los enlaces de los correos).

Los archivos (diseños, fotos, actas y soportes) van a un bucket privado de Cloudflare R2, porque el disco del servidor se borra en cada despliegue. Crea el bucket y un token de API con permiso de lectura y escritura sobre él, y define `R2_ENDPOINT`, `R2_BUCKET`, `R2_ACCESS_KEY_ID` y `R2_SECRET_ACCESS_KEY`. Ningún archivo tiene un enlace permanente: se piden en `/archivos/:id`, que revisa quién los pide (`FileAccess`) y redirige a una URL firmada que vence en 5 minutos.
