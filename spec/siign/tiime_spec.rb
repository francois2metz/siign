# frozen_string_literal: true

require 'rspec'
require 'siign'

RSpec.describe Siign::Tiime do
  let(:faraday) { double }

  def expect_authorize
    expect(faraday).to receive(:get)
      .with(
        '/authorize',
        {
          client_id: 'iEbsbe3o66gcTBfGRa012kj1Rb6vjAND',
          response_type: 'code',
          redirect_uri: 'https://apps.tiime.fr/auth-callback',
          scope: 'openid email offline_access',
          audience: 'https://chronos/',
          state: 'state'
        }
      )
      .and_return(
        double(headers: {
                 'location' => '/u/login?state=random'
               })
      )
  end

  def expect_post_user_password(user, password)
    expect(faraday).to receive(:post)
      .with('/u/login?state=random', { state: 'random', username: user })
      .and_return(
        double(headers: {
                 'location' => '/u/password?state=random'
               })
      )
    expect(faraday).to receive(:post)
      .with('/u/password?state=random', { state: 'random', username: user, password: password })
      .and_return(
        double(headers: {
                 'location' => '/u/resume?state=random'
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

  def expect_mfa_post_state
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
                 'location' => 'https://apps.tiime.fr/auth-callback?code=secret_code&scope=a&otherparams=a'
               })
      )
  end

  def expect_resume(location)
    expect(faraday).to receive(:get).with('/u/resume?state=random')
                                    .and_return(double(headers: {
                                                         'location' => location
                                                       }))
  end

  def expect_token(access_token)
    expect(faraday).to receive(:post).with('/oauth/token', {
                                             grant_type: 'authorization_code',
                                             client_id: 'iEbsbe3o66gcTBfGRa012kj1Rb6vjAND',
                                             code: 'secret_code',
                                             redirect_uri: 'https://apps.tiime.fr/auth-callback'
                                           })
                                     .and_return(double(body: {
                                                          'access_token' => access_token,
                                                          'refresh_token' => 'refresh',
                                                          'expires_in' => 86_400,
                                                          'id_token' => 'id'
                                                        }))
  end

  def expect_access_token(user, password, access_token)
    expect_authorize
    expect_post_user_password(user, password)
    expect_resume('https://apps.tiime.fr/auth-callback?code=secret_code&scope=a&otherparams=a')
    expect_token(access_token)
  end

  def expect_access_token_with_mfa(user, password, access_token)
    expect_authorize
    expect_post_user_password(user, password)
    expect_resume('/u/mfa-push-challenge?state=mfa_state')
    expect_mfa_get_state(false)
    expect_mfa_get_state(true)
    expect_mfa_post_state
    expect_token(access_token)
  end

  before do
    described_class.token = nil
    described_class.conn = nil
  end

  describe '#authenticate' do
    it 'fetch access token' do
      expect(Faraday).to receive(:new).and_return(faraday)
      expect_access_token('user', 'password', 'eee')
      token = described_class.authenticate('user', 'password')
      expect(token.access_token).to eq('eee')
      expect(token.refresh_token).to eq('refresh')
      expect(token.expires_in).to eq(86_400)
      expect(token.id_token).to eq('id')
    end

    it 'wait for mfa authorization' do
      expect(Faraday).to receive(:new).and_return(faraday)
      expect_access_token_with_mfa('user', 'password', 'eee')
      token = described_class.authenticate('user', 'password')
      expect(token.access_token).to eq('eee')
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
