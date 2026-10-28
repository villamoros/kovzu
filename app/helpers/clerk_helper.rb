module ClerkHelper
  def clerk_publishable_key
    ENV["CLERK_PUBLISHABLE_KEY"].to_s
  end

  # The publishable key encodes the instance's Frontend API host, which serves clerk-js.
  def clerk_js_url
    host = Base64.decode64(clerk_publishable_key.split("_", 3).last.to_s).delete_suffix("$")
    "https://#{host}/npm/@clerk/clerk-js@5/dist/clerk.browser.js"
  end

  def clerk_script_tag
    return if clerk_publishable_key.blank?

    tag.script(src: clerk_js_url, async: true, crossorigin: "anonymous",
      data: { clerk_publishable_key: clerk_publishable_key, turbo_track: "reload" })
  end
end
