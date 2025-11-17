# app/services/forecasts/fetch_by_address.rb
#
# Use case: free-form address to cached forecast.
# Validates, geocodes, enforces ZIP (for caching), fetches weather on miss,
# and exposes a single domain-level error.

module Forecasts
  class FetchByAddress
    # Public error type for the feature. Low-level errors are wrapped in this.
    class Error < StandardError; end

    CACHE_KEY_PREFIX = 'weather_by_zip/v1/'.freeze

    def initialize(
      geocoding_client: Geocoding::Client.new,
      weather_client:   Weather::Client.new,
      cache:            Rails.cache,
      cache_ttl:        Rails.application.config.x.forecasts.cache_ttl
    )
      @geocoding_client = geocoding_client
      @weather_client   = weather_client
      @cache            = cache
      @cache_ttl        = cache_ttl
    end

    # Main entry point for the use case.
    # Returns Forecasts::ForecastForZip or raises a domain level Error.
    def call(address)
      validate_address!(address)

      location           = geocode_address(address)
      zip_code           = extract_zip!(location)
      forecast, from_cache = fetch_forecast(location, zip_code)

      ForecastForZip.new(zip_code:, forecast:, from_cache:)
    end

    private

    def validate_address!(address)
      raise ArgumentError, 'address must be present' if address.blank?
    end

    def geocode_address(address)
      @geocoding_client.geocode(address)
    rescue Geocoding::NotFoundError
      raise Error, 'Unable to find that address.'
    rescue Geocoding::Error => e
      # Log only the exception class to avoid leaking address/PII from provider error payloads.
      Rails.logger.error("[FetchByAddress] Geocoding error: #{e.class}")
      raise Error, 'Error retrieving forecast.'
    end

    # We need to cache by ZIP so fail fast if we can't derive one.
    def extract_zip!(location)
      location.postal_code.presence ||
        raise(Error, 'Unable to determine ZIP code for that address.')
    end

    # Fetches a forecast for the coordinates and caches it by ZIP.
    # Returns [forecast, from_cache].
    def fetch_forecast(location, zip)
      from_cache = true

      forecast = @cache.fetch(cache_key(zip), expires_in: @cache_ttl) do
        from_cache = false
        @weather_client.fetch_by_coordinates(lat: location.latitude, lng: location.longitude)
      end

      [forecast, from_cache]
    rescue Weather::Error => e
      # Log only the exception class to avoid leaking address/PII from provider error payloads.
      Rails.logger.error("[FetchByAddress] Weather error: #{e.class}")
      raise Error, 'Error retrieving forecast.'
    end

    def cache_key(zip)
      "#{CACHE_KEY_PREFIX}#{zip}"
    end
  end
end
