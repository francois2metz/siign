# frozen_string_literal: true

require 'rspec'
require 'siign'

RSpec.describe Siign::Tiime do
  let(:faraday) { double }

  def expect_co_authenticate(user, password)
    expect(faraday).to receive(:post).with(
      '/co/authenticate',
      {
        client_id: 'iEbsbe3o66gcTBfGRa012kj1Rb6vjAND',
        username: user,
        password: password,
        realm: 'Chronos-prod-db',
        credential_type: 'http://auth0.com/oauth/grant-type/password-realm'
      },
      {
        origin: 'https://apps.tiime.fr'
      }
    ).and_return(double(body: { 'login_ticket' => 'lll' }))
  end

  def expect_authorize(user, access_token)
    expect(faraday).to receive(:get)
      .with(
        '/authorize',
        {
          client_id: 'iEbsbe3o66gcTBfGRa012kj1Rb6vjAND',
          response_type: 'token id_token',
          redirect_uri: "https://apps.tiime.fr/auth-callback?ctx-email=#{user}&login_initiator=user",
          scope: 'openid email',
          audience: 'https://chronos/',
          realm: 'Chronos-prod-db',
          state: 'state',
          nonce: 'nonce',
          login_ticket: 'lll'
        }
      )
      .and_return(
        double(headers: {
                 'location' => "https://apps.tiime.fr/auth-callback?ctx-email=#{user}&login_initiator=user#access_token=#{access_token}&scope=a&otherparams=a"
               })
      )
  end

  def expect_authorize_with_mfa(user)
    expect(faraday).to receive(:get)
      .with(
        '/authorize',
        {
          client_id: 'iEbsbe3o66gcTBfGRa012kj1Rb6vjAND',
          response_type: 'token id_token',
          redirect_uri: "https://apps.tiime.fr/auth-callback?ctx-email=#{user}&login_initiator=user",
          scope: 'openid email',
          audience: 'https://chronos/',
          realm: 'Chronos-prod-db',
          state: 'state',
          nonce: 'nonce',
          login_ticket: 'lll'
        }
      )
      .and_return(
        double(headers: {
                 'location' => '/u/mfa-push-challenge?state=mfa_state'
               })
      )
  end

  def expect_mfa_get_state(completed)
    expect(faraday).to receive(:get)
      .with(
        '/u/mfa-push-challenge?state=mfa_state',
        {},
        { 'Accept' => 'application/json' }
      )
      .and_return(
        double(body: {
                 'completed' => completed
               })
      )
  end

  def expect_mfa_post_state(user, access_token)
    expect(faraday).to receive(:post)
      .with(
        '/u/mfa-push-challenge?state=mfa_state'
      )
      .and_return(
        double(headers: {
                 'location' => '/authorize/resume?state=resume-state'
               })
      )
    expect(faraday).to receive(:get)
      .with(
        '/authorize/resume?state=resume-state'
      )
      .and_return(
        double(headers: {
                 'location' => "https://apps.tiime.fr/auth-callback?ctx-email=#{user}&login_initiator=user#access_token=#{access_token}&scope=a&otherparams=a"
               })
      )
  end

  def expect_access_token(user, password, access_token)
    expect_co_authenticate(user, password)
    expect_authorize(user, access_token)
  end

  def expect_access_token_with_mfa(user, password, access_token)
    expect_co_authenticate(user, password)
    expect_authorize_with_mfa(user)
    expect_mfa_get_state(false)
    expect_mfa_get_state(true)
    expect_mfa_post_state(user, access_token)
  end

  before do
    described_class.token = nil
    described_class.conn = nil
  end

  describe '#authenticate' do
    it 'fetch access token' do
      expect(Faraday).to receive(:new).and_return(faraday)
      expect_access_token('user', 'password', 'eee')
      access_token = described_class.authenticate('user', 'password')
      expect(access_token).to eq('eee')
    end

    it 'wait for mfa authorization' do
      expect(Faraday).to receive(:new).and_return(faraday)
      expect_access_token_with_mfa('user', 'password', 'eee')
      access_token = described_class.authenticate('user', 'password')
      expect(access_token).to eq('eee')
    end
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
