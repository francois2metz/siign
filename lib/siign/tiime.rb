# frozen_string_literal: true

require 'faraday'
require 'faraday-cookie_jar'

module Siign
  # Authenticate to Tiime API
  class Tiime
    class << self
      attr_writer :conn, :token

      CLIENT_ID = 'iEbsbe3o66gcTBfGRa012kj1Rb6vjAND'
      REALM = 'Chronos-prod-db'
      AUDIENCE = 'https://chronos/'

      def authenticate(user, password)
        login_ticket = authenticate_call(user, password)
        location = authorize_call(user, login_ticket)
        location = handle_mfa(location.to_s) if mfa?(location)
        extract_access_token(location)
      end

      def token(user, password)
        check_token_validity
        @token ||= authenticate(user, password)
      end

      def can_create_transaction?(quote)
        quote.status == 'saved'
      end

      def can_cancel_transaction?(quote)
        quote.status == 'saved'
      end

      private

      def conn
        @conn ||= Faraday.new(url: 'https://auth0.tiime.fr') do |f|
          f.request :json
          f.response :raise_error
          f.response :json
          f.adapter :net_http
          f.use :cookie_jar
        end
      end

      def authenticate_call(user, password)
        body = conn.post('/co/authenticate', authenticate_params(user, password),
                         { origin: 'https://apps.tiime.fr' }).body
        body['login_ticket']
      end

      def authenticate_params(user, password)
        {
          client_id: CLIENT_ID,
          username: user,
          password: password,
          realm: REALM,
          credential_type: 'http://auth0.com/oauth/grant-type/password-realm'
        }
      end

      def authorize_call(user, login_ticket)
        response = conn.get('/authorize', authorize_params(user, login_ticket))
        URI(response.headers['location'])
      end

      def authorize_params(user, login_ticket)
        {
          client_id: CLIENT_ID,
          response_type: 'token id_token',
          redirect_uri: "https://apps.tiime.fr/auth-callback?ctx-email=#{user}&login_initiator=user",
          scope: 'openid email',
          audience: AUDIENCE,
          realm: REALM,
          login_ticket: login_ticket,
          nonce: 'nonce',
          state: 'state'
        }
      end

      def mfa?(location)
        location.path == '/u/mfa-push-challenge'
      end

      def handle_mfa(location)
        wait_for_mfa_completed(location)
        response = conn.post(location)
        response = conn.get(response.headers['location'])
        URI(response.headers['location'])
      end

      def wait_for_mfa_completed(location)
        attempts = 0
        loop do
          body = conn.get(location, {}, { 'Accept' => 'application/json' }).body
          attempts += 1
          break if body['completed'] || attempts > 200

          sleep ENV['RACK_ENV'] == 'test' ? 0 : 3
        end
      end

      def extract_access_token(location)
        params = Rack::Utils.parse_query(location.fragment)
        params['access_token']
      end

      def check_token_validity
        return unless @token

        begin
          ::Tiime::User.me
        rescue Flexirest::HTTPClientException
          @token = nil
        end
      end
    end
  end
end
