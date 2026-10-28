import { Controller } from "@hotwired/stimulus"
import { esMX } from "clerk-localization-es"

// Mounts Clerk's prebuilt UI (sign in, sign up, user button) into the element.
// clerk-js is loaded once from the layout; Clerk.load() runs only once per page life.
let clerkReady

function loadClerk() {
  clerkReady ||= new Promise((resolve, reject) => {
    const start = () => {
      if (!window.Clerk) return setTimeout(start, 25)
      window.Clerk.load({ afterSignOutUrl: "/", appearance: appearance(), localization })
        .then(() => resolve(window.Clerk), reject)
    }
    start()
  })
  return clerkReady
}

// Maps KOVZU design tokens (app/assets/tailwind/kovzu/tokens.css) onto Clerk's theme.
function appearance() {
  const css = getComputedStyle(document.documentElement)
  const token = (name) => css.getPropertyValue(name).trim()

  return {
    variables: {
      colorPrimary: token("--accent"),
      colorTextOnPrimaryBackground: token("--on-accent"),
      colorBackground: token("--surface"),
      colorInputBackground: token("--surface"),
      colorText: token("--ink"),
      colorTextSecondary: token("--ink-muted"),
      colorInputText: token("--ink"),
      colorDanger: token("--danger"),
      colorSuccess: token("--success"),
      colorWarning: token("--warning"),
      borderRadius: "0.5rem",
      fontFamily: token("--font-sans")
    },
    elements: {
      rootBox: "w-full",
      cardBox: "w-full shadow-none border border-line"
    }
  }
}

// Textos de Clerk en español (es-MX, tuteo como el resto de la app) con el copy de KOVZU encima.
const localization = merge(esMX, {
  formFieldInputPlaceholder__emailAddress: "nombre@empresa.com",
  formFieldInputPlaceholder__emailAddress_username: "Correo o nombre de usuario",
  signIn: {
    start: {
      title: "Entra a KOVZU",
      subtitle: "Sigue tus pedidos, propuestas y pagos",
      actionText: "¿Aún no tienes cuenta?",
      actionLink: "Crear cuenta"
    }
  },
  signUp: {
    start: {
      title: "Crea tu cuenta",
      subtitle: "Empieza tu primer pedido en KOVZU",
      actionText: "¿Ya tienes cuenta?",
      actionLink: "Entrar"
    }
  }
})

function merge(base, extra) {
  const result = { ...base }
  for (const [key, value] of Object.entries(extra)) {
    result[key] = value && typeof value === "object" ? merge(base[key] || {}, value) : value
  }
  return result
}

// Tarjeta de entrar y crear cuenta (layouts/auth). Usa var(--token) y no valores fijos,
// así sigue al tema claro u oscuro sin volver a montar el componente.
const authAppearance = {
  layout: { logoPlacement: "none", socialButtonsVariant: "blockButton" },
  elements: {
    rootBox: { width: "100%" },
    cardBox: {
      width: "100%",
      maxWidth: "none",
      borderRadius: "var(--radius-xl)",
      border: "1px solid var(--line)",
      boxShadow: "var(--shadow-lg)",
      background: "var(--surface)"
    },
    card: {
      background: "var(--surface)",
      border: "0",
      borderRadius: "0",
      boxShadow: "none",
      padding: "2.5rem 2rem 2rem",
      gap: "1.75rem"
    },
    headerTitle: {
      fontFamily: "var(--font-display)",
      fontSize: "1.5rem",
      lineHeight: "1.25",
      fontWeight: "600",
      letterSpacing: "-0.015em",
      color: "var(--ink)"
    },
    headerSubtitle: { fontSize: "0.875rem", color: "var(--ink-muted)" },
    socialButtonsBlockButton: {
      height: "2.75rem",
      borderRadius: "var(--radius-md)",
      background: "var(--surface)",
      boxShadow: "0 0 0 1px var(--line-strong) !important",
      color: "var(--ink)",
      "&:hover": { background: "var(--surface-muted)" },
      "&:focus-visible": { outline: "2px solid var(--focus)", outlineOffset: "2px" }
    },
    socialButtonsBlockButtonText: { fontSize: "0.875rem", fontWeight: "500", color: "var(--ink)" },
    dividerLine: { background: "var(--line)" },
    dividerText: {
      fontSize: "0.6875rem",
      fontWeight: "600",
      letterSpacing: "0.12em",
      textTransform: "uppercase",
      color: "var(--ink-muted)"
    },
    formFieldLabel: { fontSize: "0.8125rem", fontWeight: "500", color: "var(--ink)" },
    formFieldInput: {
      height: "2.75rem",
      borderRadius: "var(--radius-md)",
      background: "var(--surface)",
      boxShadow: "0 0 0 1px var(--line-strong) !important",
      color: "var(--ink)",
      fontSize: "0.9375rem",
      "&::placeholder": { color: "var(--ink-muted)" },
      "&:hover": { boxShadow: "0 0 0 1px var(--ink-muted) !important" },
      "&:focus": { boxShadow: "0 0 0 1px var(--focus), 0 0 0 4px var(--focus-halo) !important" },
      "&[data-feedback='error']": { boxShadow: "0 0 0 1px var(--danger) !important" }
    },
    formButtonPrimary: {
      height: "2.75rem",
      borderRadius: "var(--radius-md)",
      border: "0",
      background: "var(--accent)",
      boxShadow: "none !important",
      color: "var(--on-accent)",
      fontSize: "0.9375rem",
      fontWeight: "600",
      textTransform: "none",
      "&::after": { display: "none" },
      "&:hover": { background: "var(--accent-hover)" },
      "&:focus-visible": { outline: "2px solid var(--focus)", outlineOffset: "2px" }
    },
    footer: {
      background: "var(--ground)",
      borderTop: "1px solid var(--line)",
      "& > div:not(:first-of-type)": { borderTop: "1px solid var(--line)" }
    },
    footerActionText: { fontSize: "0.875rem", color: "var(--ink-muted)" },
    footerActionLink: {
      fontSize: "0.875rem",
      fontWeight: "600",
      color: "var(--ink)",
      textDecoration: "underline",
      textDecorationColor: "var(--accent)",
      textDecorationThickness: "2px",
      textUnderlineOffset: "4px",
      "&:hover": { color: "var(--ink)", textDecorationColor: "var(--ink)" }
    },
    formFieldAction: { color: "var(--ink)", fontWeight: "500" },
    identityPreviewEditButton: { color: "var(--ink)" },
    otpCodeFieldInput: { borderColor: "var(--line-strong)", color: "var(--ink)" },
    badge: { background: "var(--chip)", color: "var(--ink-muted)", border: "1px solid var(--line)", boxShadow: "none" }
  }
}

export default class extends Controller {
  static values = {
    component: String,
    path: String,
    signInUrl: { type: String, default: "/sign-in" },
    signUpUrl: { type: String, default: "/sign-up" },
    redirectUrl: { type: String, default: "/dashboard" }
  }

  async connect() {
    const clerk = await loadClerk()
    if (!this.element.isConnected) return

    this.element.replaceChildren() // quita el esqueleto de carga

    switch (this.componentValue) {
      case "sign-in":
        clerk.mountSignIn(this.element, {
          routing: "path",
          path: this.pathValue || this.signInUrlValue,
          signUpUrl: this.signUpUrlValue,
          fallbackRedirectUrl: this.redirectUrlValue,
          appearance: authAppearance
        })
        break
      case "sign-up":
        clerk.mountSignUp(this.element, {
          routing: "path",
          path: this.pathValue || this.signUpUrlValue,
          signInUrl: this.signInUrlValue,
          fallbackRedirectUrl: this.redirectUrlValue,
          appearance: authAppearance
        })
        break
      case "user-button":
        clerk.mountUserButton(this.element)
        break
    }
    this.mounted = this.componentValue
  }

  disconnect() {
    if (!this.mounted || !window.Clerk) return

    const unmount = {
      "sign-in": "unmountSignIn",
      "sign-up": "unmountSignUp",
      "user-button": "unmountUserButton"
    }[this.mounted]
    window.Clerk[unmount]?.(this.element)
  }
}
