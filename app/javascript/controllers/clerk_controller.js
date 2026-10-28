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

function appearance() {
  const css = getComputedStyle(document.documentElement)
  const token = (name, fallback) => css.getPropertyValue(name).trim() || fallback

  return {
    variables: {
      colorPrimary: token("--color-accent", "#7c5cff"),
      colorBackground: token("--color-surface", "#ffffff"),
      colorText: token("--color-ink", "#0b0b10"),
      borderRadius: "0.875rem",
      fontFamily: token("--font-sans", "system-ui")
    },
    elements: {
      card: "shadow-none",
      rootBox: "w-full"
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
