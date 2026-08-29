# frozen_string_literal: true

require 'faraday'
require 'faraday-cookie_jar'

module Siign
  # Authenticate to Tiime API
  class Tiime
    class << self
      attr_writer :conn, :token

      CLIENT_ID = 'iEbsbe3o66gcTBfGRa012kj1Rb6vjAND'
      AUDIENCE = 'https://chronos/'
      REDIRECT_URI = 'https://apps.tiime.fr/auth-callback'

      def authenticate(user, password)
        location = extract_location authorize_call
        state = extract_from_query location, 'state'
        response = user_password_call location, state, user, password
        response = resume_call extract_location(response)
        location = URI(extract_location(response))
        location = handle_mfa location.to_s if mfa?(location)
        code = extract_from_query(location, 'code')
        token_call(code).body['access_token']
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

      def extract_location(response)
        response.headers['location']
      end

      def extract_from_query(location, param)
        Rack::Utils.parse_query(URI(location).query)[param]
      end

      def authorize_call
        conn.get('/authorize', authorize_params)
      end

      def authorize_params
        {
          response_type: 'code',
          client_id: CLIENT_ID,
          redirect_uri: REDIRECT_URI,
          scope: 'openid email',
          audience: AUDIENCE,
          state: 'state'
        }
      end

      def token_call(code)
        conn.post('/oauth/token', token_params(code))
      end

      def token_params(code)
        {
          grant_type: 'authorization_code',
          client_id: CLIENT_ID,
          code: code,
          redirect_uri: REDIRECT_URI
        }
      end

      def user_password_call(location, state, user, password)
        response = user_call location, state, user
        password_call extract_location(response), state, user, password
      end

      def user_call(location, state, user)
        conn.post(location, { state: state, username: user })
      end

      def password_call(location, state, user, password)
        conn.post(location, { state: state, username: user, password: password })
      end

      def resume_call(location)
        conn.get location
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
