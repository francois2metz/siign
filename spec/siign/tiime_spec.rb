# frozen_string_literal: true

require 'rspec'
require 'siign'

RSpec.describe Siign::Tiime do
  let(:faraday) { double }

  def expect_access_token(user, password, access_token)
    expect(faraday).to receive(:post).with(
      '/oauth/token',
      {
        client_id: 'iEbsbe3o66gcTBfGRa012kj1Rb6vjAND',
        username: user,
        password: password,
        grant_type: 'password',
        scope: 'openid email'
      }
    ).and_return(double(body: { 'access_token' => access_token }))
  end

  before do
    described_class.token = nil
    described_class.conn = nil
  end

  it 'fetch access token' do
    expect(Faraday).to receive(:new).and_return(faraday)
    expect_access_token('user', 'password', 'eee')
    access_token = described_class.authenticate('user', 'password')
    expect(access_token).to eq('eee')
  end

  describe '#token' do
    it 'fetch the token if doest not exist' do
      expect(Faraday).to receive(:new).and_return(faraday)
      expect_access_token('user', 'password', 'rrr')
      access_token = described_class.token('user', 'password')
      expect(access_token).to eq('rrr')
    end

    it 'returns access token if it already exist' do
      expect(Faraday).to receive(:new).and_return(faraday)
      expect_access_token('user', 'password', 'rrr')
      access_token = described_class.token('user', 'password')
      expect(access_token).to eq('rrr')
      expect(Tiime::User).to receive(:me)
      access_token2 = described_class.token('user', 'password')
      expect(access_token2).to eq('rrr')
    end

    it 'fetch the token if the token is invalid' do
      expect(Faraday).to receive(:new).and_return(faraday)
      expect_access_token('user', 'password', 'rrr')
      access_token = described_class.token('user', 'password')
      expect(access_token).to eq('rrr')
      expect(Tiime::User).to receive(:me).and_raise(Flexirest::HTTPClientException.new({ status: 401 }))
      expect_access_token('user', 'password', 'aaa')
      access_token2 = described_class.token('user', 'password')
      expect(access_token2).to eq('aaa')
    end
  end

  describe '#can_create_transaction?' do
    it 'returns true when the status is saved' do
      quote = Tiime::Quotation.new(status: 'saved')
      expect(described_class.can_create_transaction?(quote)).to be true
    end

    it 'returns true when the status is accepted' do
      quote = Tiime::Quotation.new(status: 'accepted')
      expect(described_class.can_create_transaction?(quote)).to be false
    end
  end

  describe '#can_cancel_transaction?' do
    it 'returns true when the status is saved' do
      quote = Tiime::Quotation.new(status: 'saved')
      expect(described_class.can_cancel_transaction?(quote)).to be true
    end

    it 'returns true when the status is accepted' do
      quote = Tiime::Quotation.new(status: 'accepted')
      expect(described_class.can_cancel_transaction?(quote)).to be false
    end
  end
end
