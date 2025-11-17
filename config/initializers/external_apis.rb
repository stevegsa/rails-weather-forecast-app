# config/initializers/external_apis.rb
#
# Central place for external API configuration (geocoding + weather).
# Service objects read from Rails config instead of reaching into ENV directly.

Rails.application.configure do
  # Geocoding (via Geocoder)
  config.x.geocoder.provider = :google
  config.x.geocoder.api_key  = ENV.fetch('GOOGLE_GEOCODING_API_KEY')
  config.x.geocoder.timeout  = 15

  # Weather (OpenWeather OneCall 3.0)
  config.x.weather.api_key = ENV.fetch('OPENWEATHER_API_KEY')
  config.x.weather.endpoint  = 'https://api.openweathermap.org/data/3.0/onecall'
  config.x.weather.timeout   = 5
end
