import { Controller } from "@hotwired/stimulus"

// Mounts Clerk's prebuilt UI (sign in, sign up, user button) into the element.
// clerk-js is loaded once from the layout; Clerk.load() runs only once per page life.
let clerkReady

function loadClerk() {
  clerkReady ||= new Promise((resolve, reject) => {
    const start = () => {
      if (!window.Clerk) return setTimeout(start, 25)
      window.Clerk.load({ afterSignOutUrl: "/", appearance: appearance() })
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

    switch (this.componentValue) {
      case "sign-in":
        clerk.mountSignIn(this.element, {
          routing: "path",
          path: this.pathValue || this.signInUrlValue,
          signUpUrl: this.signUpUrlValue,
          fallbackRedirectUrl: this.redirectUrlValue
        })
        break
      case "sign-up":
        clerk.mountSignUp(this.element, {
          routing: "path",
          path: this.pathValue || this.signUpUrlValue,
          signInUrl: this.signInUrlValue,
          fallbackRedirectUrl: this.redirectUrlValue
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
