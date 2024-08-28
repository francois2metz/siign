require 'faraday-cookie_jar'

module Siign
  class Authenticate
    class << self
      attr_accessor :access_token
      attr_accessor :conn

      CLIENT_ID = 'iEbsbe3o66gcTBfGRa012kj1Rb6vjAND'
      REALM = 'Chronos-prod-db'

      def conn
        @conn ||= Faraday.new(url: 'https://auth0.tiime.fr') do |f|
          f.request :json
          f.response :raise_error
          f.response :json
          f.adapter :net_http
          f.use :cookie_jar
        end
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

      def authorize_params(user, login_ticket)
        {
          client_id: CLIENT_ID,
          response_type: 'token id_token',
          redirect_uri: "https://apps.tiime.fr/auth-callback?ctx-email=#{user}&login_initiator=user",
          scope: 'openid email',
          audience: 'https://chronos/',
          realm: REALM,
          login_ticket: login_ticket,
          nonce: 'nonce',
          state: 'state',
        }
      end

      def authenticate(user, password)
        body = conn.post('/co/authenticate', authenticate_params(user, password), { origin: 'https://apps.tiime.fr' }).body
        login_ticket = body["login_ticket"]
        response = conn.get('/authorize', authorize_params(user, login_ticket))
        params = CGI::parse(URI(response.headers["location"]).fragment)
        params['access_token'].first
      end

      def get_or_fetch_token(user, password)
        check_token_validity
        @access_token ||= authenticate(user, password)
      end

      def check_token_validity
        return unless @access_token

        begin
          Tiime::User.me
        rescue Flexirest::HTTPClientException
          @access_token = nil
        end
      end
    end
  end
end
