# app/services/geocoding/client.rb
#
# Wraps the Geocoder gem behind a small interface.
# Returns a Location value object and shields callers from provider details.

module Geocoding
  class Error < StandardError; end
  class NotFoundError < Error; end

  class Client
    def geocode(address)
      result = first_geocode_result(address)

      Location.new(
        latitude: result.latitude,
        longitude: result.longitude,
        postal_code: safe_postal_code(result)
      )
    rescue StandardError => e
      # Log only the exception class to avoid leaking address/PII
      Rails.logger.error("[Geocoding::Client] #{e.class}")
      raise Error, 'Geocoding failed'
    end

    private

    # Returns the first Geocoder result or raises NotFoundError when there are none.
    def first_geocode_result(address)
      results = Geocoder.search(address)
      results.first || raise(NotFoundError, 'No geocoding results')
    end

    # Derives a postal code from a Geocoder result.
    # Uses the high-level helper when available and falls back to address_components.
    def safe_postal_code(result)
      return result.postal_code if result.postal_code.present?

      components = result.data['address_components']
      return nil unless components.is_a?(Array)

      postal = components.find { |c| c['types'].include?('postal_code') }
      postal&.dig('long_name')
    end
  end
end
