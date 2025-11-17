# spec/services/forecasts/fetch_by_address_spec.rb

require 'rails_helper'

RSpec.describe Forecasts::FetchByAddress, type: :service do
  let(:geocoding_client) { instance_double(Geocoding::Client) }
  let(:weather_client)   { instance_double(Weather::Client) }
  let(:cache)            { ActiveSupport::Cache::MemoryStore.new }
  let(:cache_ttl)        { 30.minutes }

  subject(:service) do
    described_class.new(
      geocoding_client: geocoding_client,
      weather_client: weather_client,
      cache: cache,
      cache_ttl: cache_ttl
    )
  end

  let(:location) do
    instance_double(
      'Location',
      latitude: 38.6237,
      longitude: -90.5924,
      postal_code: '99999'
    )
  end

  let(:forecast) do
    Weather::Forecast.new(
      current_temp: 72.5,
      current_description: 'clear sky',
      today_high: 78.0,
      today_low: 65.0,
      daily: []
    )
  end

  describe 'PII logging' do
    it 'does not log the address when geocoding fails' do
      allow(geocoding_client).to receive(:geocode)
        .and_raise(Geocoding::Error.new('boom: 123 Fake St'))

      expect(Rails.logger).to receive(:error) do |msg|
        expect(msg).not_to include('123 Fake St')
        expect(msg).to include('Geocoding error')
      end

      expect do
        service.call('123 Fake St')
      end.to raise_error(Forecasts::FetchByAddress::Error)
    end
  end

  describe '#call' do
    context 'when address is blank' do
      it 'raises ArgumentError' do
        expect { service.call('  ') }
          .to raise_error(ArgumentError, /address must be present/)
      end
    end

    context 'when geocoding succeeds and cache is cold' do
      it 'geocodes address, fetches forecast, and returns ForecastForZip with from_cache=false' do
        allow(geocoding_client).to receive(:geocode)
          .with('some address')
          .and_return(location)

        allow(weather_client).to receive(:fetch_by_coordinates)
          .with(lat: location.latitude, lng: location.longitude)
          .and_return(forecast)

        result = service.call('some address')

        expect(result).to be_a(Forecasts::ForecastForZip)
        expect(result.zip_code).to eq('99999')
        expect(result.forecast).to eq(forecast)
        expect(result.from_cache).to eq(false)

        # Ensure it cached the result (second call should come from cache)
        second = service.call('some address')
        expect(second.from_cache).to eq(true)
        expect(second.forecast).to eq(forecast)

        # Weather client should only be hit once because of caching
        expect(weather_client).to have_received(:fetch_by_coordinates).once
      end
    end

    context 'when geocoding returns a location without a postal code' do
      it 'raises a domain error' do
        bad_location = instance_double(
          'Location',
          latitude: 38.0,
          longitude: -90.0,
          postal_code: nil
        )

        allow(geocoding_client).to receive(:geocode).and_return(bad_location)

        expect { service.call('no-zip address') }
          .to raise_error(described_class::Error, /Unable to determine ZIP code/)
      end
    end

    context 'when geocoding client raises NotFoundError' do
      it 'wraps it in a domain error with a friendly message' do
        allow(geocoding_client).to receive(:geocode)
          .and_raise(Geocoding::NotFoundError.new('no results'))

        expect { service.call('missing') }
          .to raise_error(described_class::Error, 'Unable to find that address.')
      end
    end

    context 'when geocoding client raises Geocoding::Error' do
      it 'wraps it in a generic forecast error' do
        allow(geocoding_client).to receive(:geocode)
          .and_raise(Geocoding::Error.new('boom'))

        expect { service.call('addr') }
          .to raise_error(described_class::Error, 'Error retrieving forecast.')
      end
    end

    context 'when weather client raises Weather::Error' do
      it 'wraps it in a generic forecast error' do
        allow(geocoding_client).to receive(:geocode).and_return(location)
        allow(weather_client).to receive(:fetch_by_coordinates)
          .and_raise(Weather::Error.new('weather down'))

        expect { service.call('addr') }
          .to raise_error(described_class::Error, 'Error retrieving forecast.')
      end
    end
  end
end
