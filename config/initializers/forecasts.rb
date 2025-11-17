# config/initializers/forecast.rb
#
# Forecast related settings.
# Cache expiry is configured per environment.

Rails.application.configure do
  # How long to cache forecasts keyed by ZIP code.
  config.x.forecasts.cache_ttl = 30.minutes
end
