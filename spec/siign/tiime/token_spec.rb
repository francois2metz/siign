# frozen_string_literal: true

require 'rspec'
require 'timecop'
require 'siign'

RSpec.describe Siign::Tiime::Token do
  describe '.from_response' do
    it 'create a token from the response' do
      token = described_class.from_response(
        {
          'access_token' => 'a',
          'refresh_token' => 'r',
          'id_token' => 'i',
          'expires_in' => 100
        }
      )
      expect(token.access_token).to eq('a')
      expect(token.refresh_token).to eq('r')
      expect(token.id_token).to eq('i')
      expect(token.expires_in).to eq(100)
    end
  end

  describe '#expired?' do
    it 'not expired' do
      token = described_class.new('a', 'r', 'i', 1000)
      expect(token).not_to be_expired
    end

    it 'expired' do
      token = described_class.new('a', 'r', 'i', 1000)
      Timecop.travel(1001)
      expect(token).to be_expired
    end
  end

  describe '#update' do
    it 'update the infos stored' do
      token = described_class.new('a', 'r', 'i', 1000)
      Timecop.travel(1001)
      expect(token).to be_expired
      token.update(described_class.from_response(
                     {
                       'access_token' => 'a2',
                       'id_token' => 'i2',
                       'expires_in' => 200
                     }
                   ))
      expect(token.access_token).to eq('a2')
      expect(token.id_token).to eq('i2')
      expect(token.expires_in).to eq(200)
      expect(token).not_to be_expired
    end
  end
end
