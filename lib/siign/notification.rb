# frozen_string_literal: true

require 'faraday'

module Siign
  # Send http notification
  class Notification
    def notify(status, quote_title)
      notification_url = ENV.fetch('NOTIFICATION_URL', nil)
      return if notification_url.nil?

      msg = notification_msg(status, quote_title)
      return if msg.nil?

      Faraday.get(notification_url.gsub(/\${msg}/, ERB::Util.url_encode(msg)))
    end

    private

    def notification_msg(status, quote_title)
      case status
      when :signed
        "Bonne nouvelle, devis #{quote_title} signé !"
      when :refused
        "Mauvaise nouvelle, devis #{quote_title} refusé !"
      when :expired
        "Sale nouvelle, devis #{quote_title} expiré !"
      when :aborted
        "Sale nouvelle, devis #{quote_title} annulé !"
      end
    end
  end
end
