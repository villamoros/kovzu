# Clerk authentication. CLERK_PUBLISHABLE_KEY and CLERK_SECRET_KEY are read
# from the environment (.env locally, the host's env vars in production).
Clerk.configure do |c|
  c.excluded_routes = [ "/up", "/csp-reports", "/assets/*", "/icon.png", "/icon.svg" ]
  c.cache_store = Rails.cache
end
