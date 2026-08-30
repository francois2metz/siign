# frozen_string_literal: true

module Siign
  class Tiime
    # Store token related info
    class Token
      class << self
        def from_response(body)
          Token.new(body['access_token'], body['refresh_token'], body['id_token'], body['expires_in'])
        end
      end

      attr_reader :access_token, :refresh_token, :id_token, :expires_in

      def initialize(access_token, refresh_token, id_token, expires_in)
        @access_token = access_token
        @refresh_token = refresh_token
        @id_token = id_token
        @expires_in = expires_in
        @expires_at = Time.now.to_i + expires_in
      end

      def expired?
        Time.now.to_i > @expires_at
      end

      def update(new_token)
        @access_token = new_token.access_token
        @access_token = new_token.access_token
        @id_token = new_token.id_token
        @expires_in = new_token.expires_in
        @expires_at = Time.now.to_i + expires_in
      end
    end
  end
end
