# app/services/forecasts/forecast_for_zip.rb
#
# Result object for a forecast lookup keyed by ZIP.
# Used as the return type for Forecasts::FetchByAddress.

module Forecasts
  ForecastForZip = Struct.new(
    :zip_code,
    :forecast,
    :from_cache,
    keyword_init: true
  )
end
