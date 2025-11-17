# spec/services/geocoding/client_spec.rb

require 'rails_helper'

RSpec.describe Geocoding::Client, type: :service do
  subject(:client) { described_class.new }

  let(:address) { '123 Fake St 99999' }

  describe '#geocode' do
    let(:result) do
      instance_double(
        'GeocoderResult',
        latitude: 38.6237,
        longitude: -90.5924,
        postal_code: '99999',
        data: {}
      )
    end

    context 'when Geocoder returns at least one result' do
      it 'returns a Location with latitude, longitude, and postal_code' do
        allow(Geocoder).to receive(:search).with(address).and_return([result])

        location = client.geocode(address)

        expect(location.latitude).to eq(38.6237)
        expect(location.longitude).to eq(-90.5924)
        expect(location.postal_code).to eq('99999')
      end
    end

    context 'when there are no geocoding results' do
      it 'raises Geocoding::Error' do
        allow(Geocoder).to receive(:search).with(address).and_return([])

        expect do
          client.geocode(address)
        end.to raise_error(Geocoding::Error, 'Geocoding failed')
      end
    end

    context 'when a lower-level error occurs' do
      it 'wraps it in Geocoding::Error' do
        allow(Geocoder).to receive(:search).and_raise(StandardError.new('boom'))

        expect do
          client.geocode(address)
        end.to raise_error(Geocoding::Error, 'Geocoding failed')
      end
    end
  end

  describe '#safe_postal_code' do
    let(:base_result) do
      instance_double(
        'GeocoderResult',
        postal_code: postal_code,
        data: data
      )
    end

    context 'when postal_code is present directly' do
      let(:postal_code) { '99999' }
      let(:data) { {} }

      it 'returns the direct postal_code' do
        expect(client.send(:safe_postal_code, base_result)).to eq('99999')
      end
    end

    context 'when postal_code is nil but present in address_components' do
      let(:postal_code) { nil }
      let(:data) do
        {
          'address_components' => [
            { 'long_name' => '99999', 'types' => ['postal_code'] }
          ]
        }
      end

      it 'extracts the postal_code from address_components' do
        expect(client.send(:safe_postal_code, base_result)).to eq('99999')
      end
    end

    context 'with a realistic Google result payload' do
      let(:postal_code) { nil }
      let(:data) do
        {
          'address_components' => [
            { 'long_name' => 'Apple Park Way', 'short_name' => 'Apple Park Way', 'types' => ['route'] },
            { 'long_name' => 'Cupertino', 'short_name' => 'Cupertino', 'types' => %w[locality political] },
            { 'long_name' => 'Santa Clara County', 'short_name' => 'Santa Clara County',
              'types' => %w[administrative_area_level_2 political] },
            { 'long_name' => 'California', 'short_name' => 'CA',
              'types' => %w[administrative_area_level_1 political] },
            { 'long_name' => 'United States', 'short_name' => 'US', 'types' => %w[country political] },
            { 'long_name' => '95014', 'short_name' => '95014', 'types' => ['postal_code'] }
          ],
          'formatted_address' => 'Apple Park Way, Cupertino, CA 95014, USA',
          'geometry' => {},
          'partial_match' => true,
          'place_id' => 'ChIJTZmAhJC1j4ARbyia3aT-W-c',
          'types' => ['route']
        }
      end

      it 'extracts the postal_code from address_components' do
        expect(client.send(:safe_postal_code, base_result)).to eq('95014')
      end
    end

    context 'when address_components is missing or not an array' do
      let(:postal_code) { nil }
      let(:data) { {} }

      it 'returns nil' do
        expect(client.send(:safe_postal_code, base_result)).to be_nil
      end
    end
  end
end
