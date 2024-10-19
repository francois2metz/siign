# frozen_string_literal: true

require 'faraday'

module Siign
  # Send http notification
  class Notification
    def notify(msg)
      notification_url = ENV.fetch('NOTIFICATION_URL', nil)
      return if notification_url.nil?

      return if msg.nil?

      Faraday.get(notification_url.gsub(/\${msg}/, ERB::Util.url_encode(msg)))
    end
  end
end
