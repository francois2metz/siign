# frozen_string_literal: true

require 'faraday'

module Siign
  # Authenticate to Tiime API
  class Tiime
    class << self
      attr_writer :conn, :token

      CLIENT_ID = 'iEbsbe3o66gcTBfGRa012kj1Rb6vjAND'

      def authenticate(user, password)
        body = conn.post('/oauth/token', token_params(user, password)).body
        body['access_token']
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
        end
      end

      def token_params(user, password)
        {
          grant_type: 'password',
          client_id: CLIENT_ID,
          username: user,
          password: password,
          scope: 'openid email',
          audience: 'https://chronos/'
        }
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
