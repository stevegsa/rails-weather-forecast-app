# app/services/weather/client.rb
#
# Thin wrapper around the OpenWeather OneCall 3.0 API.
# Responsible for:
#   - validating coordinates
#   - performing the HTTP call
#   - mapping JSON into Forecast / Daily objects
#   - turning upstream failures into Weather::Error

module Weather
  class Error < StandardError; end

  class Client
    # Number of days to expose in the extended forecast.
    EXTENDED_FORECAST_DAYS = 5

    def initialize(
      api_key:   Rails.application.config.x.weather.api_key,
      http:      HTTParty,
      endpoint:  Rails.application.config.x.weather.endpoint,
      timeout:   Rails.application.config.x.weather.timeout
    )
      @api_key  = api_key
      @http     = http
      @endpoint = endpoint
      @timeout  = timeout
    end

    def fetch_by_coordinates(lat:, lng:)
      validate_coordinates!(lat, lng)

      response = perform_request(lat, lng)
      build_forecast(response)
    rescue Net::ReadTimeout, Net::OpenTimeout => e
      log_timeout(e)
      raise Error, 'Weather API timeout'
    rescue Weather::Error
      # Already normalized; let it bubble up unchanged.
      raise
    end

    private

    def validate_coordinates!(lat, lng)
      return if lat.present? && lng.present?

      raise ArgumentError, 'latitude/longitude must be present'
    end

    def perform_request(lat, lng)
      @http.get(
        @endpoint,
        query: build_query(lat, lng),
        timeout: @timeout
      )
    end

    def build_query(lat, lng)
      {
        lat: lat,
        lon: lng, # API uses `lon`, we use `lng` internally
        units: 'imperial', # Fahrenheit / mph
        exclude: 'minutely,alerts', # we don't use these so exclude them to reduce packet size
        appid: @api_key
      }
    end

    def build_forecast(response)
      ensure_success!(response)

      body    = response.parsed_response
      current = body.fetch('current')
      daily   = body.fetch('daily')
      today   = daily.first

      Forecast.new(
        current_temp: current['temp'],
        current_description: current.dig('weather', 0, 'description'),
        today_high: today.dig('temp', 'max'),
        today_low: today.dig('temp', 'min'),
        daily: build_daily_forecasts(daily)
      )
    end

    def ensure_success!(response)
      return if response.success?

      Rails.logger.error("[Weather::Client] HTTP #{response.code}")
      raise Error, "Weather API error (status #{response.code})"
    end

    def build_daily_forecasts(daily)
      daily.first(EXTENDED_FORECAST_DAYS).map do |d|
        Daily.new(
          date: Time.at(d['dt']).to_date,
          high: d.dig('temp', 'max'),
          low: d.dig('temp', 'min'),
          description: d.dig('weather', 0, 'description')
        )
      end
    end

    def log_timeout(error)
      Rails.logger.error("[Weather::Client] timeout: #{error.class}")
    end
  end
end
