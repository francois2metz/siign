# frozen_string_literal: true

require 'faraday'

module Siign
  # Send quote notification
  class QuoteNotification
    def notify(status, quote_title)
      Notification.new.notify(notification_msg(status, quote_title))
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
