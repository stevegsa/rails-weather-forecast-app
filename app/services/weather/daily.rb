# app/services/weather/daily.rb
#
# Single-day forecast, as returned by OpenWeather's daily data.

module Weather
  Daily = Struct.new(
    :date,
    :high,
    :low,
    :description,
    keyword_init: true
  )
end
