# spec/requests/forecasts_spec.rb

require 'rails_helper'

RSpec.describe 'Forecasts', type: :request do
  describe 'GET /forecasts/new' do
    it 'renders successfully' do
      get new_forecast_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Weather Forecast')
    end
  end

  describe 'POST /forecasts' do
    let(:service) { instance_double(Forecasts::FetchByAddress) }

    let(:forecast) do
      Weather::Forecast.new(
        current_temp: 72.5,
        current_description: 'clear sky',
        today_high: 78.0,
        today_low: 65.0,
        daily: []
      )
    end

    let(:detailed_forecast) do
      Forecasts::ForecastForZip.new(
        zip_code: '99999',
        forecast: forecast,
        from_cache: false
      )
    end

    before do
      allow(Forecasts::FetchByAddress).to receive(:new).and_return(service)
    end

    it 'renders the forecast on success' do
      allow(service).to receive(:call).and_return(detailed_forecast)

      post forecasts_path, params: { address: '123 Fake St 99999' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Zip Code 99999')
      expect(response.body).to include('clear sky')
    end

    it 're-renders with a validation error for blank address' do
      post forecasts_path, params: { address: '' }

      expect(response.body).to include('Please enter an address.')
    end

    it 're-renders with a domain error when service fails' do
      allow(service).to receive(:call)
        .and_raise(Forecasts::FetchByAddress::Error, 'Unable to find that address.')

      post forecasts_path, params: { address: 'bad address' }

      expect(response.body).to include('Unable to find that address.')
    end
  end
end
