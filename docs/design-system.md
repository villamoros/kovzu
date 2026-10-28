# Sistema de diseño KOVZU

Base visual de la app, sacada del *Manual de identidad v1.0* (27 oct 2026). Funciona con Rails 8, `tailwindcss-rails` (Tailwind v4), importmap y Stimulus.

## Qué incluye

| Archivo | Qué hace |
| --- | --- |
| `app/assets/tailwind/kovzu/tokens.css` | Colores, tipografía, radios y sombras. Modo claro y oscuro. Los expone como utilidades de Tailwind (`bg-surface`, `text-ink-muted`, `border-line`, `bg-accent`…). |
| `app/assets/tailwind/kovzu/components.css` | Componentes `kz-*`: botón, estado, tarjeta, indicador, tabla, formulario, línea de tiempo, barra superior, ficha técnica, aviso, capacidad. |
| `app/helpers/kz_helper.rb` | `kz_logo`, `kz_icon`, `kz_capability`, `kz_status`, `kz_glyph`, `kz_date` y el catálogo de estados. |
| `app/views/kz/` | Parciales: `_head` (fuentes y tema), `_app_header`, `_page_header` (título, estado y acciones), `_errors` (errores de formulario), `_stat`, `_timeline`, `_flash`. |
| `app/javascript/controllers/theme_controller.js` | Botón de modo claro/oscuro. Recuerda la elección y, si no hay, sigue al sistema. |
| `app/javascript/controllers/dismiss_controller.js` | Cierra avisos, a mano o tras unos segundos. |
| `app/assets/images/kovzu/` | Logo (símbolo, firma corta y firma completa, positivo y negativo) y los 6 iconos de capacidad. |
| `app/views/layouts/auth.html.erb` | Diseño de entrar y crear cuenta: panel azul con retícula y rutas (`layouts/_auth_network`), mensaje (`sessions/_pitch`) y la tarjeta de Clerk. Las clases son `kz-auth*`. |
| `app/javascript/controllers/clerk_controller.js` | Monta Clerk con los textos en español (`vendor/javascript/clerk-localization-es.js`, es-MX) y viste la tarjeta de acceso con los tokens (`var(--accent)`, `var(--line-strong)`…), así sigue al tema. |
| `app/controllers/design_system_controller.rb` + `app/views/design_system/show.html.erb` | Catálogo vivo para revisar todo en la app. |

## Instalación en la app

1. En `app/assets/tailwind/application.css`, después de `@import "tailwindcss";`:

   ```css
   @import "./kovzu/tokens.css";
   @import "./kovzu/components.css";
   ```

2. En `app/views/layouts/application.html.erb`, dentro de `<head>` y antes de `stylesheet_link_tag`:

   ```erb
   <%= render "kz/head" %>
   ```

   Y en el `<body>`:

   ```erb
   <body class="bg-ground text-ink font-sans antialiased">
     <%= render "kz/app_header", items: [["Pedidos", "#"], ["Talleres", "#"], ["Inspecciones", "#"]] %>
     <%= render "kz/flash" %>
     <%= yield %>
   </body>
   ```

3. En `config/routes.rb`, para ver el catálogo en desarrollo:

   ```ruby
   get "/design", to: "design_system#show", as: :design if Rails.env.development?
   ```

   Abre `http://localhost:3000/design`.

Los controladores de Stimulus se registran solos con `eagerLoadControllersFrom`.

## Reglas de uso

- **Lima (`accent`) es para la acción principal, el foco y la selección.** Un botón primario por vista. Nunca texto lima sobre marfil: no se lee.
- **Azul profundo (`ink`) es el texto y la estructura.** `ink-muted` para texto secundario. `ink-subtle` (gris industrial) solo para iconos y marcas, no para texto pequeño.
- **Separar con líneas finas (`line`), no con sombras.** Las sombras quedan para menús y diálogos.
- **Cada pedido muestra qué pasó, qué sigue y quién debe actuar.** Usa `kz_status` para el estado y `kz/timeline` para los hitos.
- **Estados:** chip neutro con punto de color. Solo las excepciones (rechazo, reproceso) se tiñen en rojo completo. El catálogo de etiquetas y tonos está en `app/models/status_catalog.rb` (pedido, subpedido, requerimiento, ficha, cotización y taller).
- **Tipografía:** Sora para títulos (`kz-display`, `kz-h1`, `kz-h2`, `kz-h3`), Inter para todo lo demás. Códigos de pedido con `kz-code`.
- **Retícula de 8 px.** Usa la escala de espaciado de Tailwind en pasos de 2 (`gap-2`, `p-4`, `p-6`…).
- **Tono de voz:** claro y sin promesas absolutas. Evita "calidad perfecta", "cero defectos" o "entrega garantizada". "Taller verificado" describe el proceso de KOVZU, no una certificación.

## Ejemplos

```erb
<button class="kz-btn kz-btn--primary"><%= kz_glyph :plus %>Nuevo pedido</button>
<button class="kz-btn kz-btn--outline">Ver ficha técnica</button>

<%= kz_status sub_order.status, kind: :sub_order %>
<%= kz_status "verificado", kind: :workshop %>

<%= render "kz/stat", label: "En producción", value: "07", tone: :info %>

<%= kz_capability "empaques" %>
<%= kz_logo :symbol, class: "h-8" %>

<div class="kz-field">
  <label class="kz-label" for="pedido_cantidad">Cantidad</label>
  <%= f.number_field :cantidad, class: "kz-input" %>
</div>
```

## Pendientes

- Los iconos de capacidad se redibujaron en SVG a partir de las imágenes del manual (64 px, trazo 2.7). Si el diseñador entrega los vectores originales, reemplazar los archivos de `app/assets/images/kovzu/icons/`.
- El manual pide validar el contraste real en la interfaz final: las combinaciones de texto de este sistema ya cumplen 4.5:1 en claro y oscuro.
