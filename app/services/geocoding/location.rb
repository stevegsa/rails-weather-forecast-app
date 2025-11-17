# app/services/geocoding/location.rb
module Geocoding
  Location = Struct.new(:latitude, :longitude, :postal_code, keyword_init: true)
end
