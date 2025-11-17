# app/services/weather/forecast.rb
#
# Aggregate forecast exposed to the UI:
# - current conditions
# - today's high/low
# - multi day forecast

module Weather
  Forecast = Struct.new(
    :current_temp,
    :current_description,
    :today_high,
    :today_low,
    :daily,
    keyword_init: true
  )
end
