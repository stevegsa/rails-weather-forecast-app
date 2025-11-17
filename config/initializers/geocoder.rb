# config/initializers/geocoder.rb
#
# Configure Geocoder to read its settings from Rails config.
# This lets each environment override provider, timeout and API key.

Geocoder.configure(
  lookup: Rails.application.config.x.geocoder.provider,
  timeout: Rails.application.config.x.geocoder.timeout,
  api_key: Rails.application.config.x.geocoder.api_key,
  # Disable provider-level logging in production to avoid leaking addresses
  logger: Rails.env.production? ? Logger.new(nil) : Rails.logger
)
