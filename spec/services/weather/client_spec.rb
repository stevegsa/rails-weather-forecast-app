# spec/services/weather/client_spec.rb

require 'rails_helper'

RSpec.describe Weather::Client, type: :service do
  let(:http)     { instance_double('HttpClient') }
  let(:api_key)  { 'test-api-key' }
  let(:endpoint) { 'https://example.com/onecall' }
  let(:timeout)  { 2 }

  subject(:client) do
    described_class.new(
      api_key: api_key,
      http: http,
      endpoint: endpoint,
      timeout: timeout
    )
  end

  let(:lat) { 38.6 }
  let(:lng) { -90.5 }

  let(:openweather_body) do
    JSON.parse(
      File.read(Rails.root.join('spec/fixtures/weather/openweather_one_call_sample.json'))
    )
  end

  describe '#fetch_by_coordinates' do
    context 'when the response is successful' do
      let(:response) do
        instance_double(
          'Response',
          success?: true,
          parsed_response: openweather_body
        )
      end

      it 'maps current and daily fields into a Forecast object' do
        expect(http).to receive(:get).with(
          endpoint,
          query: {
            lat: lat,
            lon: lng,
            units: 'imperial',
            exclude: 'minutely,alerts',
            appid: api_key
          },
          timeout: timeout
        ).and_return(response)

        forecast = client.fetch_by_coordinates(lat: lat, lng: lng)

        expect(forecast).to be_a(Weather::Forecast)

        # current
        expect(forecast.current_temp).to eq(openweather_body.dig('current', 'temp'))
        expect(forecast.current_description)
          .to eq(openweather_body.dig('current', 'weather', 0, 'description'))

        # today's high/low (first daily)
        first_daily = openweather_body.dig('daily', 0)
        expect(forecast.today_high).to eq(first_daily.dig('temp', 'max'))
        expect(forecast.today_low).to eq(first_daily.dig('temp', 'min'))

        # extended forecast
        expect(forecast.daily).to all(be_a(Weather::Daily))
        expect(forecast.daily.first.date)
          .to eq(Time.at(first_daily['dt']).to_date)
      end
    end

    context 'when coordinates are missing' do
      it 'raises ArgumentError if lat is blank' do
        expect { client.fetch_by_coordinates(lat: nil, lng: lng) }
          .to raise_error(ArgumentError, %r{latitude/longitude must be present})
      end

      it 'raises ArgumentError if lng is blank' do
        expect { client.fetch_by_coordinates(lat: lat, lng: nil) }
          .to raise_error(ArgumentError, %r{latitude/longitude must be present})
      end
    end

    context 'when the response is not successful' do
      let(:response) do
        instance_double(
          'Response',
          success?: false,
          code: 500,
          body: 'Internal Server Error'
        )
      end

      it 'raises Weather::Error with an appropriate message' do
        allow(http).to receive(:get).and_return(response)

        expect do
          client.fetch_by_coordinates(lat: lat, lng: lng)
        end.to raise_error(Weather::Error, /Weather API error/)
      end
    end

    context 'when a timeout occurs' do
      it 'logs and raises a Weather::Error with timeout message' do
        allow(http).to receive(:get).and_raise(Net::ReadTimeout)

        expect do
          client.fetch_by_coordinates(lat: lat, lng: lng)
        end.to raise_error(Weather::Error, 'Weather API timeout')
      end
    end

    context 'when an unexpected error occurs' do
      it 'logs and raises the error' do
        allow(http).to receive(:get).and_raise(StandardError.new('boom'))

        expect do
          client.fetch_by_coordinates(lat: lat, lng: lng)
        end.to raise_error(StandardError, 'boom')
      end
    end
  end
end
